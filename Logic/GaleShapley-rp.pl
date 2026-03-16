% GaleShapley-rp.pl
%
% This program runs the Gale-Shapley stable matching algorithm for
% residents and medical residency programs. Each resident has a list
% of programs they'd prefer to go to, and each program has its own
% ranking of residents plus a quota of available positions.
%
% The algorithm keeps letting residents "offer" themselves to programs
% until the system settles down and nobody wants to move anymore.
% Once that happens, we print the results both to the console and
% to a file called rp.txt.

:- discontiguous resident/3.
:- discontiguous program/4.
% These lines just tell Prolog not to complain if resident and program
% facts appear in different parts of the file.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Residents
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% resident(+ResidentID, +NameStructure, +ROL)
%
% Stores the information for one resident.
%
% Parameters
% ResidentID     : Unique numeric identifier for the resident
% NameStructure  : Name stored as name(FirstName,LastName)
% ROL            : Rank Order List of program IDs, ordered from
%                  most preferred to least preferred.
%
% Example:
% resident(574, name(salvatore,williams), [nrs,hep,mmi]).
%
% Meaning:
% Resident 574 prefers Neurosurgery first, then Hematological
% Pathology, then Microbiology.

resident(574, name(salvatore,williams), [nrs,hep,mmi]).
resident(517, name(rosalie,frederick), [nrs,mmi]).
resident(126, name(indie,medrano), [mmi,nrs]).
resident(828, name(emma,tremmo), [obg,nrs]).
resident(403, name(aspyn,olson), [hep,nrs]).
resident(226, name(zev,jarvis), [mmi,hep,nrs]).
resident(913, name(camille,paquet), [obg,mmi,hep]).
resident(773, name(marie,clown), [obg]).
resident(616, name(laurent,robert), [obg,mmi,hep,nrs]).
resident(377, name(tom,tan), [mmi,obg]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Programs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% program(+ProgramID, +ProgramName, +Quota, +ROL)
%
% Stores the information for a residency program.
%
% Parameters
% ProgramID   : Unique identifier for the program
% ProgramName : Full human-readable program name
% Quota       : Number of residents the program can accept
% ROL         : Rank Order List of resident IDs, ordered from
%               most preferred to least preferred.
%
% If a resident does not appear in this list, that program will
% never accept them.

program(nrs,"Neurosurgery",4,[574,517,403,828,226,126]).
program(obg,"Obstetrics and Gynecology",3,[616,828,773,913]).
program(mmi,"Microbiology",1,[574,517,226,913,377,126]).
program(hep,"Hematological Pathology",2,[403,574,913,616,226]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rankInProgram
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% rankInProgram(+ResidentID, +ProgramID, -Rank)
%
% Determines the ranking position of a resident inside a program's
% preference list.
%
% Parameters
% ResidentID : ID of the resident being checked
% ProgramID  : Program whose ranking list we are looking at
% Rank       : Position of the resident in that program's ROL
%
% Example
% rankInProgram(403,nrs,R).
% R = 3
%
% Meaning the program ranked resident 403 as their 3rd choice.

rankInProgram(RID,PID,Rank) :-
    program(PID,_,_,ROL),
    nth1(Rank,ROL,RID).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% leastPreferred
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% leastPreferred(+ProgramID, +ResidentList, -ResidentID, -Rank)
%
% Finds the least preferred resident currently matched to a program.
% This is used when the program is already full and needs to decide
% whether a new applicant should replace someone already there.
%
% Parameters
% ProgramID     : Program whose ranking list we use
% ResidentList  : List of residents currently matched to the program
% ResidentID    : The least preferred resident in that list
% Rank          : The ranking position of that resident in the
%                 program's ROL.

leastPreferred(P,[H|T],Rid,Rank) :-
    rankInProgram(H,P,R),
    leastPreferredAux(T,P,H,R,Rid,Rank).

% leastPreferredAux(+RemainingResidents,+ProgramID,+CurrentWorst,
%                   +CurrentRank,-FinalWorst,-FinalRank)
%
% Helper predicate used by leastPreferred/4. It walks through the
% list of residents and keeps track of the lowest ranked one.

leastPreferredAux([],_,Rid,Rank,Rid,Rank).
leastPreferredAux([H|T],P,CR,CRank,Rid,Rank) :-
    ( rankInProgram(H,P,R), R > CRank ->
        NR = H, NRank = R
    ;
        NR = CR, NRank = CRank
    ),
    leastPreferredAux(T,P,NR,NRank,Rid,Rank).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% matched
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% matched(+ResidentID, -ProgramID, +MatchSet)
%
% Checks whether a resident is currently matched to a program.
%
% Parameters
% ResidentID : Resident being checked
% ProgramID  : Program they are matched to
% MatchSet   : Current list of program-resident matches
%
% MatchSet structure example:
% [match(nrs,[126,517,574]), match(obg,[616,773,828]), ...]

matched(RID,PID,MS) :-
    member(match(PID,Residents),MS),
    member(RID,Residents), !.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% offer
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% offer(+ResidentID,+CurrentMatchSet,-NewMatchSet)
%
% Main step of the Gale-Shapley algorithm. A resident attempts to
% match with programs in their preference list until one accepts
% them or they run out of options.
%
% Parameters
% ResidentID      : Resident currently trying to match
% CurrentMatchSet : Current set of program-resident matches
% NewMatchSet     : Updated match set after the offer attempt

offer(RID,MS,MS) :-
    matched(RID,_,MS), !.

offer(RID,MS,NewMS) :-
    resident(RID,_,Prefs),
    offerList(RID,Prefs,MS,NewMS).

% offerList(+ResidentID,+ProgramList,+MatchSet,-NewMatchSet)
%
% Walks through a resident's preference list and tries programs
% one at a time until a match is found.

offerList(_,[],MS,MS).

offerList(R,[P|Rest],MS,NewMS) :-

    program(P,_,_,ROL),

    % Skip program if resident not in its ranking list
    \+ member(R,ROL), !,
    offerList(R,Rest,MS,NewMS).

offerList(R,[P|Rest],MS,NewMS) :-

    select(match(P,Residents),MS,Others),
    program(P,_,Quota,_),
    length(Residents,L),

    (
        % Program still has room
        L < Quota ->
            append(Residents,[R],NewResidents),
            NewMS = [match(P,NewResidents)|Others]

    ;

        % Program is full, check if new resident is preferred
        leastPreferred(P,Residents,Rid,RankOld),
        rankInProgram(R,P,RankNew),

        ( RankNew < RankOld ->

            % Replace the worst resident
            select(Rid,Residents,Remaining),
            append(Remaining,[R],Updated),
            TempMS = [match(P,Updated)|Others],

            offer(Rid,TempMS,NewMS)

        ;

            % Try next program in resident list
            offerList(R,Rest,MS,NewMS)
        )
    ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Gale-Shapley iteration
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% galeLoop(+ResidentList,+CurrentMatchSet,-NewMatchSet)
%
% Processes one round of offers for every resident.

galeLoop([],MS,MS).
galeLoop([R|Rest],MS,Final) :-
    offer(R,MS,NewMS),
    galeLoop(Rest,NewMS,Final).

% galeFixpoint(+Residents,+MatchSet,-FinalMatchSet)
%
% Repeatedly runs galeLoop until the match set stops changing.
% When no further changes occur, the matching is stable.

galeFixpoint(Residents,MS,Final) :-
    galeLoop(Residents,MS,NewMS),
    ( MS = NewMS ->
        Final = MS
    ;
        galeFixpoint(Residents,NewMS,Final)
    ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Printing helpers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% writeMatch(+ResidentID,+ProgramID,+Stream)
%
% Prints one successful resident-program match to the
% output file and the console.

writeMatch(R,P,Stream) :-
    resident(R,name(FN,LN),_),
    program(P,Title,_,_),
    format(Stream,'~w,~w,~w,~w,~w~n',[LN,FN,R,P,Title]),
    format('~w,~w,~w,~w,~w~n',[LN,FN,R,P,Title]).

% writeUnmatched(+ResidentID,+Stream)
%
% Prints a resident who did not match any program.

writeUnmatched(R,Stream) :-
    resident(R,name(FN,LN),_),
    format(Stream,'~w,~w,~w,XXX,NOT_MATCHED~n',[LN,FN,R]),
    format('~w,~w,~w,XXX,NOT_MATCHED~n',[LN,FN,R]).

% printResidents(+ResidentList,+MatchSet,+Stream,+Acc,+FinalCount)
%
% Prints the final match status for every resident and keeps
% track of how many ended up unmatched.

printResidents([],_,_,U,U).
printResidents([R|Rest],MS,Stream,Acc,Final) :-
    (
        matched(R,P,MS) ->
            writeMatch(R,P,Stream),
            NewAcc = Acc
        ;
            writeUnmatched(R,Stream),
            NewAcc is Acc + 1
    ),
    printResidents(Rest,MS,Stream,NewAcc,Final).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Available positions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% availablePositions(+MatchSet,-TotalOpenPositions)
%
% Counts how many residency spots remain unfilled after the
% matching process finishes.

availablePositions([],0).
availablePositions([match(P,Rs)|Rest],Total) :-
    program(P,_,Quota,_),
    length(Rs,L),
    Rem is Quota - L,
    availablePositions(Rest,T2),
    Total is Rem + T2.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Top-level predicate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% gale_shapley
%
% Main entry point of the program.
% Steps:
% 1. Build an empty match set for all programs
% 2. Collect and sort all residents
% 3. Run Gale-Shapley until the matching stabilizes
% 4. Print the final results
% 5. Save them to rp.txt

gale_shapley :-

    findall(match(P,[]),program(P,_,_,_),InitMS),
    findall(R,resident(R,_,_),Res),
    sort(Res,Residents),

    galeFixpoint(Residents,InitMS,FinalMS),

    open('rp.txt',write,Stream),

    printResidents(Residents,FinalMS,Stream,0,Unmatched),
    availablePositions(FinalMS,Avail),

    format(Stream,'Number of unmatched residents: ~w~n',[Unmatched]),
    format(Stream,'Number of positions available: ~w~n',[Avail]),

    format('Number of unmatched residents: ~w~n',[Unmatched]),
    format('Number of positions available: ~w~n',[Avail]),

    close(Stream),

    writeln('Results written to rp.txt').