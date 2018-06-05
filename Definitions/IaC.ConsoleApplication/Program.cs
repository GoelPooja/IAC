using System;
using IaC.ExcelParser;

namespace IaCModel.ConsoleApplication
{
    class Program
    {
        
        static void Main(string[] args)
        {
            string EXCEL_PATH = @"C:\git\IAC\Server Role Templates.xlsx";
            Parser parser = new Parser(EXCEL_PATH);
            var templates = parser.ReadExcelFile();
            Console.ReadLine();

        }
    }
}
