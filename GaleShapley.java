// Project CSI2120/CSI2520
// Winter 2026
// Robert Laganiere, uottawa.ca
import java.io.*;
import java.util.HashMap;
import java.util.ArrayList;

// this is the (incomplete) class that will generate the resident and program maps
public class GaleShapley {
	
	public HashMap<Integer,Resident> residents;
	public HashMap<String,Program> programs;
	

public GaleShapley(String residentsFilename, String programsFilename)
        throws IOException, NumberFormatException {

    readResidents(residentsFilename);
    readPrograms(programsFilename);

    ArrayList<String> matches = new ArrayList<>();
    ArrayList<String> unmatched = new ArrayList<>();

    // free residents queue
    ArrayList<Resident> free = new ArrayList<>(residents.values());

    while (!free.isEmpty()) {

        Resident r = free.remove(0);
        String pid = r.proposeNextProgram();

        // resident exhausted all options
        if (pid == null) {
            unmatched.add(r.toString());
            continue;
        }

        Program p = programs.get(pid);

        // program does not exist → try next
        if (p == null) {
            free.add(r);
            continue;
        }

        int rid = r.getID();

        // program does NOT rank resident → reject
        if (!p.ranks(rid)) {
            free.add(r);
            continue;
        }

        // program has space
        if (p.hasSpace()) {
            p.addResident(rid);
            r.setMatchedProgram(pid);
        } 
        else {
            int worst = p.getWorstMatchedResident();

            // program prefers new resident
            if (p.prefers(rid, worst)) {

                p.removeResident(worst);
                residents.get(worst).setMatchedProgram(null);
                free.add(residents.get(worst));

                p.addResident(rid);
                r.setMatchedProgram(pid);

            } else {
                // rejected → resident remains free
                free.add(r);
            }
        }
    }

    // build output
    for (Resident r : residents.values()) {
        if (r.getMatchedProgram() != null) {
            matches.add(r + " -> " + r.getMatchedProgram());
        }
    }

    BufferedWriter writer = new BufferedWriter(new FileWriter("matches.txt"));

    writer.write("MATCHES\n");
    for (String m : matches) {
        writer.write(m);
        writer.newLine();
    }

    writer.newLine();
    writer.write("UNMATCHED\n");
    for (String u : unmatched) {
        writer.write(u);
        writer.newLine();
    }

    writer.close();
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

	public static void main(String[] args) {
		
		
		try {
			
			GaleShapley gs= new GaleShapley(args[0],args[1]);
			
			System.out.println(gs.residents);
			System.out.println(gs.programs);
			
        } catch (Exception e) {
            System.err.println("Error reading the file: " + e.getMessage());
        }
	}
}
