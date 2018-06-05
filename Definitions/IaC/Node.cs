using System; 
using System.Collections.Generic;

namespace IaC.Model
{
	public class Node
	{
		public string Name { get; set; }
		public int Instances { get; set; }
		public int Cores { get; set; }
		public int Memory { get; set; }
		public List<int> Disks { get; set; }
		public string Layer { get; set; }
		private Dictionary<string, ClusterEndpoint> clusterEndpoints;
        private Dictionary<string, Role> roles;
        public void AddRole(Role role)
        {
            if (!this.roles.ContainsKey(role.Name))
            {
                this.roles.Add(role.Name, role);
            }
            //else throw new Exception("Tried to add role that already exists!");
        }
        public List<Role> Roles
        {
            get { return new List<Role>(this.roles.Values); }
        }

        public Node()
        {
            this.clusterEndpoints = new Dictionary<string, ClusterEndpoint>();
            this.Disks = new List<int>();
            this.roles = new Dictionary<string, Role>();
        }
		public Node(string name, int instances, int cores, int memory, int disk1, int disk2, int disk3, string layer)
		{
			this.Name = name;
			this.Instances = instances;
			this.Cores = cores;
			this.Memory = memory;
			this.Disks = new List<int>();
			if (disk1 > 0) this.Disks.Add(disk1);
			if (disk2 > 0) this.Disks.Add(disk2);
			if (disk3 > 0) this.Disks.Add(disk3);
			this.Layer = layer;
			this.clusterEndpoints = new Dictionary<string, ClusterEndpoint>();
            this.roles = new Dictionary<string, Role>();
        }
        private List<ClusterEndpoint> getClusterEndpoints(string type)
        {
            List<ClusterEndpoint> clusterEndpoints = new List<ClusterEndpoint>();
            foreach (ClusterEndpoint clusterEndpoint in this.clusterEndpoints.Values)
                if (clusterEndpoint.Type == type)
                    clusterEndpoints.Add(clusterEndpoint);
            return clusterEndpoints;
        }
        public List<ClusterEndpoint> WSFCClusterEndpoints
        {
            get { return this.getClusterEndpoints("WSFC"); }
        }
        public List<ClusterEndpoint> NLBClusterEndpoints
        {
            get { return this.getClusterEndpoints("NLB"); }
        }

        public List<ClusterEndpoint> AAGClusterEndpoints
        {
            get { return this.getClusterEndpoints("AAG"); }
        }

        public IEnumerable<ClusterEndpoint> ClusterEndpoints { get { return this.clusterEndpoints.Values; } }

        public void AddClusterEndpoint (ClusterEndpoint clusterEndpoint)
        {
            if (!this.clusterEndpoints.ContainsKey(clusterEndpoint.Key))
                this.clusterEndpoints.Add(clusterEndpoint.Key, clusterEndpoint);
        }
    }
}