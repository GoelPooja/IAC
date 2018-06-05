using IaC.Model;
using Microsoft.Office.Interop.Excel;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;

namespace IaC.ExcelParser
{
    public class Parser
    {
        string excelPath;
        Application excelApplication;
        Workbook excelWorkBook;

        public Parser(string excelPath)
        {
            this.excelPath = excelPath;
        }

        public List<Template> ReadExcelFile()
        {
            List<Template> parsedOutput = new List<Template>();
            try { openFile(); parsedOutput = parseFile(); }
            catch (Exception ex) { Console.WriteLine(ex.Message); }
            finally { closeFile(); }
            return parsedOutput;
        }

        private List<Template> parseFile()
        {
            //retrieving the worksheet counts inside the excel workbook  
            int workSheetCounts = excelWorkBook.Worksheets.Count;
            int totalColumns = 0;
            Range cell;
            List<Template> templates = new List<Template>();

            for (int sheetCounter = 1; sheetCounter <= workSheetCounts; sheetCounter++)
            {
                Worksheet workSheet = (Worksheet)excelWorkBook.Sheets[sheetCounter];
                totalColumns = workSheet.UsedRange.Cells.Columns.Count;

                //Iterate through templates
                for (int wsCol = 1; wsCol <= totalColumns; wsCol++)
                {
                    //Template Headers are in row 2
                    cell = (Range)workSheet.Cells[2, wsCol];

                    //Found template header
                    if ((bool)cell.MergeCells)
                    {
                        var colSpan = cell.MergeArea.Columns.Count;
                        int tCol = wsCol;
                        wsCol += colSpan - 1;

                        string templateName = getMergedCellValue(cell);
                        if (templateName == "") { continue; }

                        Template template = GetTemplate(workSheet, tCol, templateName);
                        templates.Add(template);
                    }
                }
            }

            return templates;
        }

        private static Template GetTemplate(Worksheet workSheet, int tCol, string templateName)
        {
            Template template = new Template(templateName);

            //Iterate through nodes
            for (int row = 3; row <= workSheet.UsedRange.Cells.Rows.Count; row++)
            {
                Range nodeCell = (Range)workSheet.Cells[row, tCol];
                var nodeRowSpan = nodeCell.MergeArea.Rows.Count;
                Node node = GetNode(workSheet, tCol, row, nodeRowSpan);
                template.AddNode(node);
                row += nodeRowSpan - 1;
            }

            return template;
        }

        private static Node GetNode(Worksheet workSheet, int tCol, int row, int nodeRowSpan)
        {
            Node node = new Node();
            node.Name = GetCellValue(workSheet, row, tCol + 0);
            node.Instances = int.Parse(GetCellValue(workSheet, row, tCol + 1));
            node.Cores = int.Parse(GetCellValue(workSheet, row, tCol + 2));
            node.Memory = int.Parse(GetCellValue(workSheet, row, tCol + 3));
            node.Layer = GetCellValue(workSheet, row, tCol + 7);
            node.Disks.Add(int.Parse(GetCellValue(workSheet, row, tCol + 4)));
            node.Disks.Add(int.Parse(GetCellValue(workSheet, row, tCol + 5)));
            node.Disks.Add(int.Parse(GetCellValue(workSheet, row, tCol + 6)));

            Dictionary<string, ClusterEndpoint> clusterEndpoints = new Dictionary<string, ClusterEndpoint>();
            Dictionary<string, Role> roles = new Dictionary<string, Role>();

            // Iterate through roles
            for (int rrow = row; rrow < row + nodeRowSpan; rrow++)
            {
                Role role = GetRole(workSheet, rrow);

                for (int i = 0; i < role.Endpoints.Count; i++)
                {
                    string endpointKey = role.Endpoints[i].Key;
                    if (clusterEndpoints.ContainsKey(endpointKey))
                    {
                        // replace the reference with the existing
                        clusterEndpoints[endpointKey].AddPorts(role.Endpoints[i].Ports);
                        role.Endpoints[i] = clusterEndpoints[endpointKey];
                    }
                    else
                    {
                        // add the new object to the dictionary
                        clusterEndpoints.Add(endpointKey, role.Endpoints[i]);
                    }
                    // Add the role reference to the new or existing endpoint
                    clusterEndpoints[endpointKey].AddRole(role);                    
                }
                node.AddRole(role);
                if (rrow >= workSheet.UsedRange.Cells.Rows.Count) break;
            }
            foreach (ClusterEndpoint clusterEndpoint in clusterEndpoints.Values)
            {
                node.AddClusterEndpoint(clusterEndpoint);
            }

            return node;
        }

        private static Role GetRole(Worksheet workSheet, int rrow)
        {
            Role role = new Role();
            role.Name = GetCellValue(workSheet, rrow, 2);
            string aliasesString = GetCellValue(workSheet, rrow, 3);
            var aliases = string.IsNullOrEmpty(aliasesString) ? new string[] { } : aliasesString.Split(new string[] { "\n" }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string a in aliases) role.AddAlias(a);
            role.Tag = GetCellValue(workSheet, rrow, 6);
            string accountsString = GetCellValue(workSheet, rrow, 7);
            var accounts = string.IsNullOrEmpty(accountsString) ? new string[] { } : accountsString.Split(new string[] { "\n" }, StringSplitOptions.RemoveEmptyEntries);

            string csvTemplates = GetCellValue(workSheet, rrow, 4);
            string csvPorts = GetCellValue(workSheet, rrow, 5);

            string[] templates = string.IsNullOrEmpty(csvTemplates) ? new string[] { } : csvTemplates.Split(new string[] { "," }, StringSplitOptions.RemoveEmptyEntries);
            string[] portLines = string.IsNullOrEmpty(csvPorts) ? new string[] { } : csvPorts.Split(new string[] { "," }, StringSplitOptions.RemoveEmptyEntries);

            int numClusterEndpoints = templates.Length;
            for (int i = 0; i < numClusterEndpoints; i++)
            {
                string[] templateParts = string.IsNullOrEmpty(templates[i]) ? new string[] { } : templates[i].Split(new string[] { ":" }, StringSplitOptions.RemoveEmptyEntries);
                string type = templateParts[0].Trim();
                string template = templateParts[1];
                string[] ports = string.IsNullOrEmpty(portLines[i]) ? new string[] { } : portLines[i].Split(new string[] { "\n" }, StringSplitOptions.RemoveEmptyEntries);
                var newEndpoint = new ClusterEndpoint(template, type);
                foreach (string p in ports) newEndpoint.AddPort(int.Parse(p));
                role.Endpoints.Add(newEndpoint);
            }
            foreach (string a in accounts) role.AddAccount(a);
            return role;
        }

        private static string GetCellValue(Worksheet workSheet, int row, int nodeCol)
        {
            Range cell = (Range)workSheet.Cells[row, nodeCol];
            if ((bool)cell.MergeCells) { return getMergedCellValue(cell); }
            return (cell.Value ?? string.Empty).ToString();
        }

		private static dynamic getMergedCellValue(Range cell)
        {      
            return Convert.ToString(((Range)cell.MergeArea[1, 1]).Text).Trim();
        }

        private void openFile()
        {
            this.excelApplication = new Application();
            this.excelWorkBook = excelApplication.Workbooks.Open(excelPath);
        }
        private void closeFile()
        {
            //Release the Excel objects     
            excelWorkBook.Close(false, System.Reflection.Missing.Value, System.Reflection.Missing.Value);
            excelApplication.Workbooks.Close();
            excelApplication.Quit();
            excelApplication = null;
            excelWorkBook = null;

            GC.GetTotalMemory(false);
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();
            GC.GetTotalMemory(true);
        }
    }
}
