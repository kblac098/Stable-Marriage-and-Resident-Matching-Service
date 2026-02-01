// Project CSI2120/CSI2520
// Winter 2026
// Robert Laganiere, uottawa.ca
import java.io.*;
import java.util.*;

// this is the (incomplete) class that will generate the resident and program maps
public class GaleShapley {
	
	public HashMap<Integer,Resident> residents;
	public HashMap<String,Program> programs;
	

	public GaleShapley(String residentsFilename, String programsFilename) throws IOException, 
													NumberFormatException {
		
		readResidents(residentsFilename);
		readPrograms(programsFilename);

		System.out.println(residents.get(616));
		System.out.println(programs.get("OBG"));

	}
	
	// Reads the residents csv file
	// It populates the residents HashMap
    public void readResidents(String residentsFilename) throws IOException, 
													NumberFormatException {

        String line;
		residents= new HashMap<Integer,Resident>();
		BufferedReader br = new BufferedReader(new FileReader(residentsFilename)); 

		int residentID;
		String firstname;
		String lastname;
		String plist;
		String[] rol;

		// Read each line from the CSV file
		line = br.readLine(); // skipping first line
		while ((line = br.readLine()) != null && line.length() > 0) {

			int split;
			int i;

			// extracts the resident ID
			for (split=0; split < line.length(); split++) {
				if (line.charAt(split) == ',') {
					break;
				} 
			}
			if (split > line.length()-2)
				throw new IOException("Error: Invalid line format: " + line);

			residentID= Integer.parseInt(line.substring(0,split));
			split++;

			// extracts the resident firstname
			for (i= split ; i < line.length(); i++) {
				if (line.charAt(i) == ',') {
					break;
				} 
			}
			if (i > line.length()-2)
				throw new IOException("Error: Invalid line format: " + line);

			firstname= line.substring(split,i);
			split= i+1;
			
			// extracts the resident lastname
			for (i= split ; i < line.length(); i++) {
				if (line.charAt(i) == ',') {
					break;
				} 
			}
			if (i > line.length()-2)
				throw new IOException("Error: Invalid line format: " + line);

			lastname= line.substring(split,i);
			split= i+1;		
				
			Resident resident= new Resident(residentID,firstname,lastname);

			for (i= split ; i < line.length(); i++) {
				if (line.charAt(i) == '"') {
					break;
				} 
			}
			
			// extracts the program list
			plist= line.substring(i+2,line.length()-2);
			String delimiter = ","; // Assuming values are separated by commas
			rol = plist.split(delimiter);
			
			resident.setROL(rol);
			
			residents.put(residentID,resident);
		}	
    }

	
	// Reads the programs csv file
	// It populates the programs HashMap
    public void readPrograms(String programsFilename) throws IOException, 
													NumberFormatException {

        String line;
		programs= new HashMap<String,Program>();
		BufferedReader br = new BufferedReader(new FileReader(programsFilename)); 

		String programID;
		String name;
		int quota;
		String rlist;
		int[] rol;

		// Read each line from the CSV file
		line = br.readLine(); // skipping first line
		while ((line = br.readLine()) != null && line.length() > 0) {

			int split;
			int i;

			// extracts the program ID
			for (split=0; split < line.length(); split++) {
				if (line.charAt(split) == ',') {
					break;
				} 
			}			
			if (split > line.length()-2)
				throw new IOException("Error: Invalid line format: " + line);


			programID= line.substring(0,split);
			split++;

			// extracts the program name
			for (i= split ; i < line.length(); i++) {
				if (line.charAt(i) == ',') {
					break;
				} 
			}
			if (i > line.length()-2)
				throw new IOException("Error: Invalid line format: " + line);
			
			name= line.substring(split,i);
			split= i+1;
			
			// extracts the program quota
			for (i= split ; i < line.length(); i++) {
				if (line.charAt(i) == ',') {
					break;
				} 
			}
			if (i > line.length()-2)
				throw new IOException("Error: Invalid line format: " + line);

			quota= Integer.parseInt(line.substring(split,i));
			split= i+1;		
				
			Program program= new Program(programID,name,quota);

			for (i= split ; i < line.length(); i++) {
				if (line.charAt(i) == '"') {
					break;
				} 
			}
			
			// extracts the resident list
			rlist= line.substring(i+2,line.length()-2);
			String delimiter = ","; // Assuming values are separated by commas
			String[] rol_string = rlist.split(delimiter);
			rol= new int[rol_string.length];
			for (int j=0; j<rol_string.length; j++) {
				
				rol[j]= Integer.parseInt(rol_string[j]);
			}
			
			program.setROL(rol);
			
			programs.put(programID,program);
		}	
    }

	public int unmatchedResidents() {
		int count = 0;
		for (Resident r : residents.values()) {
			if (r.getMatchedProgram() == null) {
				count ++;
			}
		}
		return count;
	}

	public int positionsAvailable() {
		int totalpositionsAvailable = 0;
		for (Program p : programs.values()) {
			totalpositionsAvailable += (p.getQuota() - p.getMatchedResidents().size());
		}
		return totalpositionsAvailable;
	}

	/**
	 * The while loop works as follows:
	 * while the queue is not empty the first resident is popped to propose to their next preference
	 * if the resident is not on the programs preference list then they are added back to the queue to try their next choice.
	 * if program has space then resident is accepted and status is updated.
	 * if program is full then it compares the applicant to its current least preferred resident.
	 * Loop ends when no more residents can make proposals.
	 */
	public void galeShapley() {

		Queue<Resident> available = new LinkedList<>();

		for (Resident r: residents.values()) {
			available.add(r);
		}


		//this means the while loop will loop while there are still residents who can be matched.
		while(!available.isEmpty()) {
			Resident r = available.poll(); //pick the first available resident.

			String nextProgramID = r.getNextProgramID();

			if(nextProgramID != null) {
				Program p = programs.get(nextProgramID);

				if(p != null && p.member(r.getResidentID())) {
					Resident leastBefore = p.leastPreferred();

					p.addResident(r);

					if (r.getMatchedProgram() == null) {
						available.add(r);
					}

					else if (leastBefore != null && leastBefore.getMatchedProgram() == null) {
						available.add(leastBefore);
					}
				} else {

					available.add(r);
				}
			}

		}
	}

	public void output(String results) throws IOException {
			PrintWriter writer = new PrintWriter(new FileWriter(results));

			ArrayList<Resident> rList = new ArrayList<>(residents.values());

			Collections.sort(rList, new Comparator<Resident>() {
				@Override
				public int compare(Resident r1, Resident r2) {
					return r1.getLastName().compareTo(r2.getLastName());
				}
			});

			for (Resident r : rList) {
				String programID = r.getMatchedProgram();
				if (programID == null) {
					writer.printf("%s, %s, %d, XXX, NOT_MATCHED%n",
															r.getLastName(), r.getFirstName(), r.getResidentID());

				} else {
					Program p = programs.get(programID);
					writer.printf("%s, %s, %d, %s, %s%n", r.getLastName(), r.getFirstName(), r.getResidentID(), p.getProgramID(), p.getName());
				}
			}

			writer.println("Number of unmatched residents: " + unmatchedResidents());
    		writer.println("Number of positions available: " + positionsAvailable());
    		writer.close();
		}

	public static void main(String[] args) {
		
		try {
			
			GaleShapley gs= new GaleShapley(args[0],args[1]);
			gs.galeShapley();

			gs.output("matches.txt");
			
			System.out.println("Matching Successful. Results saved to matches.txt");
			
			System.out.println(gs.residents);
			System.out.println(gs.programs);
			
        } catch (Exception e) {
            System.err.println("Error reading the file: " + e.getMessage());
        }
	}
}
