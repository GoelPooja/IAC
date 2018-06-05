using System;
using System.Collections.Generic;

namespace IaC.Model
{
	public class Template
	{
		public string Name { get; private set; }
		private readonly Dictionary<string, Node> nodes;

		public Template(string name)
		{
			this.Name = name;
			this.nodes = new Dictionary<string, Node>();
			this.AccountPasswords = new Dictionary<string, string>();
		}

		public void AddNode(Node node)
		{
			if (!nodes.ContainsKey(node.Name))
			{
				this.nodes.Add(node.Name, node);
			}
			else throw new Exception("Tried to add node that already exists!");
		}

		public List<Node> Nodes
		{
			get { return new List<Node>(this.nodes.Values); }
		}

		public List<string> ServiceAccounts
		{
			get
			{
				List<string> serviceAccounts = new List<string>();
				foreach (Node n in this.Nodes)                   
					foreach (Role r in n.Roles)
						foreach (string a in r.Accounts)
							if (!serviceAccounts.Contains(a))
								serviceAccounts.Add(a);
				return serviceAccounts;
			}
		}

		public Dictionary<string,ClusterEndpoint> Aliases
		{
			get
			{
                Dictionary<string, ClusterEndpoint> aliases = new Dictionary<string, ClusterEndpoint>();
				foreach (Node n in this.Nodes)
                        foreach (Role r in n.Roles)
                            foreach (string a in r.Aliases)
							if (!aliases.ContainsKey(a))
								aliases.Add(a,r.DefaultEndpoint);
				return aliases;
			}
		}

		public Dictionary<string, string> AccountPasswords { get; set; }
	}
}