using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using IaC.ExcelParser;
using IaC.Model;

namespace Tests
{
    [TestClass]
    public class ExcelFileTests
    {
        [TestMethod]
        public void TryReadTemplates()
        {
            string ExcelFileName =  @"Server Role Templates.xlsx";
            string ExcelFileFullPath = Environment.CurrentDirectory + "\\" + ExcelFileName;
            Console.WriteLine(ExcelFileFullPath);
            Parser parser = new Parser(ExcelFileFullPath);
            var templates = parser.ReadExcelFile();
        }
    }
}
