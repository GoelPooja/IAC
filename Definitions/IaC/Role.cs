using System;
using System.Collections.Generic;
using System.Linq;

namespace IaC.Model
{
    public class Role
    {
        public string Name { get; set; }
        public string Tag { get; set; }
        private List<string> accounts;
		private List<string> aliases;
        public List<ClusterEndpoint> Endpoints { get; set; }
        public ClusterEndpoint DefaultEndpoint
        {
            get { return this.Endpoints.FirstOrDefault(); }
        }

        public Role()
        {
            this.accounts = new List<string>();
            this.aliases = new List<string>();
            this.Endpoints = new List<ClusterEndpoint>();
        }
        public Role(string name, string tag)
        {
            this.Name = name;
            this.Tag = tag;
            this.accounts = new List<string>();
            this.aliases = new List<string>();
            this.Endpoints = new List<ClusterEndpoint>();
        }
        public void AddAccount(string account)
        {
            if (!accounts.Contains(account))
                accounts.Add(account);
        }
		public void AddAlias(string alias)
		{
			if (!this.aliases.Contains(alias))
				this.aliases.Add(alias);
		}
        public List<string> Accounts { get { return this.accounts; } }
		public List<string> Aliases { get { return this.aliases; } }
    }
}