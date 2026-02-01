// Project CSI2120/CSI2520
// Winter 2026
// Robert Laganiere, uottawa.ca

import java.util.ArrayList;

// this is the (incomplete) Program class
public class Program {
	
	private String programID;
	private String name;
	private int quota;
	private int[] rol;
	private ArrayList<Integer> matchedResidents;
	
	// constructs a Program
    public Program(String id, String n, int q) {
	
		programID= id;
		name= n;
		quota= q;
		matchedResidents = new ArrayList<>();
	}

    // the rol in order of preference
	public void setROL(int[] rol) {
		
		this.rol= rol;
	}

	public boolean hasSpace() {
	    return matchedResidents.size() < quota;
	}

	public void addResident(int r) {
	    matchedResidents.add(r);
	}

	public void removeResident(int r) {
	    matchedResidents.remove(Integer.valueOf(r));
	}

	public boolean ranks(int r) {
	    return indexOf(r) != Integer.MAX_VALUE;
	}
	
	public int getWorstMatchedResident() {
	    int worst = matchedResidents.get(0);
	    for (int r : matchedResidents) {
	        if (indexOf(r) > indexOf(worst)) {
	            worst = r;
	        }
	    }
	    return worst;
	}
	
	public boolean prefers(int r1, int r2) {
	    int rank1 = indexOf(r1);
	    int rank2 = indexOf(r2);
	    return rank1 < rank2;
	}

	private int indexOf(int r) {
	    for (int i = 0; i < rol.length; i++) {
	        if (rol[i] == r) return i;
	    }
	    return Integer.MAX_VALUE;
	}

	public String getID() { return programID; }
	public String getName() { return name; }
	public int getQuota() { return quota; }
	public int[] getROL() { return rol; }
	
	// string representation
	public String toString() {
      
       return "["+programID+"]: "+name+" {"+ quota+ "}" +" ("+rol.length+")";	  
	}
}