using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IaC.Model
{
    public class ClusterEndpoint
    {
        public string Type { get; set; }
        public string Template { get; set; }
        public string VIPAddress { get; set; }
        private List<int> ports;
        private List<Role> roles;

        public string Key { get { return this.Type + this.Template; } }

        public ClusterEndpoint(string template,string type)
        {
            this.Template = template;
            this.Type = type;
            this.ports = new List<int>();
            this.roles = new List<Role>();
        }

        public List<int> Ports
        {
            get { return this.ports; }
        }
        public void AddPorts(List<int> ports)
        {
            foreach (int port in ports)
                if (!this.ports.Contains(port))
                    this.ports.Add(port);
        }

        public void AddPort(int port)
        {
            if (port >= 0 && port <= 65536)
            {
                if (!this.ports.Contains(port))
                    this.ports.Add(port);
            }
            else throw new Exception("Port outside valid range.");
        }

        public void AddRole(Role role)
        {
            if (!this.roles.Contains(role))
                this.roles.Add(role);
            else throw new Exception("there is a logic error here");
        }
    }
}
