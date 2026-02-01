import java.util.ArrayList;
// Project CSI2120/CSI2520
// Winter 2026
// Robert Laganiere, uottawa.ca

// this is the (incomplete) Program class
public class Program {
	
	private String programID;
	private String name;
	private int quota;
	private int[] rol;
	private ArrayList<Resident> matchedResidents; //new instance variable to ensure every new Program object has a place to store its matches.
	
	// constructs a Program
    public Program(String id, String n, int q) {
	
		programID= id;
		name= n;
		quota= q;
		this.matchedResidents = new ArrayList<>();
	}

    // the rol in order of preference
	public void setROL(int[] rol) {
		
		this.rol= rol;
	}

	public String getProgramID() {
		return programID;
	}

	public boolean member(int residentID) {
		return rank(residentID) != -1;
	}

	public String getName() {
		return this.name;
	}

	public int getQuota() {
		return quota;
	}

	public ArrayList getMatchedResidents() {
		return matchedResidents;
	}

	//* this return the rank (index) of any resident in the program ROL
	// Residents with a lower rank have a higher priority. */
	public int rank(int residentID) {
		for (int i = 0; i < rol.length; i++) {
			if (rol[i] == residentID) {
				return i;
			}
		}
		return -1;
	}

	/**
	 * identify which resident has the highest rank (worst match)
	 * @return the resident r that has the highest rank.
	 */
	public Resident leastPreferred() {
		if (matchedResidents.isEmpty()) {
			return null;
		}

		Resident worst = matchedResidents.get(0);

		for (Resident r : matchedResidents) {
			if (rank(r.getResidentID()) > rank(worst.getResidentID())) {
				worst = r;
			}
		}

		return worst;
	}

	/**
	 * This method first checks if the program has space to match the resident. If it does then it matches the resident immediately.
	 * If full, then it finds the highest ranked resident and compares it with the new resident
	 * Then it resets the matched program for the worst candidate to null and sets their rank to -1 as they no longer have any programs they are applying to.
	 * @param r
	 */
	public void addResident(Resident r) {
		if (matchedResidents.size() < quota) {
			matchedResidents.add(r);
			r.setMatchedProgram(this.programID);
			r.setMatchedRank(rank(r.getResidentID()));
			return;
		}

		//case 2. the program is full so the code will find the worst current match

		Resident worst = leastPreferred();

		//swap if the new resident is preferred over the worst ranked resident.
		if (rank(r.getResidentID()) < rank(worst.getResidentID())) {
			
			//remove the worst resident
			matchedResidents.remove(worst);
			worst.setMatchedProgram(null);

			//this makes sure the worst resident that got bumped out is made available again.
			worst.setMatchedRank(-1);
			
			//add new resident
			matchedResidents.add(r);
			r.setMatchedProgram(programID);
			r.setMatchedRank(rank(r.getResidentID()));
		}

		
	}
	
	// string representation
	public String toString() {
      
       return "["+programID+"]: "+name+" {"+ quota+ "}" +" ("+rol.length+")";	  
	}
}