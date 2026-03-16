%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GaleShapley-rp.pl
%
% Runs the Gale-Shapley stable matching algorithm for
% residents and residency programs. Each resident has
% a preference list, and each program has its own ranking
% and quota of available spots.
%
% Residents "offer" themselves to programs one by one.
% Programs accept residents if they have space, or swap
% out their least preferred if the new one is better.
% The process repeats until things settle down and nobody
% wants to move anymore.
%
% Results are printed to the console and saved to rp.txt.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- discontiguous resident/3.
:- discontiguous program/4.
:- dynamic rank_table/3.
% These lines just tell Prolog to chill if facts appear in
% different parts and allow us to dynamically store the rank table.

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Precompute rank table
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% buildRankTable/0
%
% Builds rank_table(ProgramID, ResidentID, Rank) for fast lookup
% This saves time when checking who’s least preferred.
%
% No parameters.

buildRankTable :-
    retractall(rank_table(_,_,_)),
    forall(program(P,_,_,ROL),
        (
            nth1(Rank,ROL,RID),
            assertz(rank_table(P,RID,Rank)),
            fail
        );
        true
    ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rankInProgram
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% rankInProgram(+ResidentID, +ProgramID, -Rank)
%
% Gives the rank of a resident in a program’s list quickly.
% Uses the precomputed rank_table so we don’t have to scan lists.
%
% ResidentID : ID of the resident we’re checking
% ProgramID  : ID of the program
% Rank       : position in the program’s ROL (1 is best)

rankInProgram(RID,PID,Rank) :- 
    rank_table(PID,RID,Rank), !.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% leastPreferred
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% leastPreferred(+ProgramID, +ResidentList, -ResidentID, -Rank)
%
% Finds the least liked resident in a program’s current matches.
% Used when a program is full and has to decide if a new applicant
% is better than someone already there.
%
% ProgramID   : program checking its residents
% ResidentList: list of resident IDs currently matched
% ResidentID  : ID of the least preferred resident
% Rank        : rank of that resident in the program’s ROL

leastPreferred(P,Residents,Rid,Rank) :-
    Residents = [H|_],
    rankInProgram(H,P,Rank0),
    leastPreferredAux(Residents,P,H,Rank0,Rid,Rank).

% leastPreferredAux(+RemainingResidents, +ProgramID, +CurrentWorst,
%                  +CurrentRank, -FinalWorst, -FinalRank)
%
% Helper for leastPreferred. Walks the list and keeps track
% of the lowest-ranked resident so far.

leastPreferredAux([],_,CR,CRank,CR,CRank).
leastPreferredAux([H|T],P,CR,CRank,Rid,Rank) :-
    rankInProgram(H,P,RH),
    ( RH > CRank -> NR = H, NRank = RH ; NR = CR, NRank = CRank ),
    leastPreferredAux(T,P,NR,NRank,Rid,Rank).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% matched
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% matched(+ResidentID, -ProgramID, +MatchSet)
%
% True if the resident is currently matched to a program.
%
% ResidentID : ID of resident to check
% ProgramID  : program they’re matched to
% MatchSet   : current program-resident matches

matched(RID,PID,MS) :-
    member(match(PID,Residents),MS),
    member(RID,Residents), !.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% offer
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% offer(+ResidentID, +CurrentMatchSet, -NewMatchSet)
%
% Main step of Gale-Shapley. Resident tries to get matched
% with programs in their preference order until someone accepts.

offer(RID,MS,MS) :- matched(RID,_,MS), !.
offer(RID,MS,NewMS) :-
    resident(RID,_,Prefs),
    offerList(RID,Prefs,MS,NewMS).

% offerList(+ResidentID, +ProgramList, +MatchSet, -NewMatchSet)
%
% Walks through a resident’s preference list one by one
% Tries to get in. Handles full programs and replacing
% least preferred residents if necessary.

offerList(_,[],MS,MS).
offerList(R,[P|Rest],MS,NewMS) :-
    rank_table(P,R,_), !,
    select(match(P,Residents),MS,Others),
    program(P,_,Quota,_),
    length(Residents,L),
    (
        L < Quota ->  % room in program, just add resident
            append(Residents,[R],NewResidents),
            NewMS = [match(P,NewResidents)|Others]
        ;
            % program full, see if new resident is better
            leastPreferred(P,Residents,Rid,RankOld),
            rankInProgram(R,P,RankNew),
            ( RankNew < RankOld ->
                select(Rid,Residents,Remaining),
                append(Remaining,[R],Updated),
                TempMS = [match(P,Updated)|Others],
                offer(Rid,TempMS,NewMS)
            ;
                offerList(R,Rest,MS,NewMS)
            )
    ).
offerList(R,[_|Rest],MS,NewMS) :-
    offerList(R,Rest,MS,NewMS).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Gale-Shapley iteration
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% galeLoop(+ResidentList, +CurrentMatchSet, -NewMatchSet)
%
% Goes through all residents once, letting them offer themselves
% to programs in order.

galeLoop([],MS,MS).
galeLoop([R|Rest],MS,Final) :-
    offer(R,MS,NewMS),
    galeLoop(Rest,NewMS,Final).

% galeFixpoint(+Residents, +MatchSet, -FinalMatchSet)
%
% Keeps running galeLoop until the matches stop changing.
% That’s when the matching is stable.

galeFixpoint(Residents,MS,Final) :-
    galeLoop(Residents,MS,NewMS),
    ( MS = NewMS -> Final = MS
    ; galeFixpoint(Residents,NewMS,Final)
    ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Printing helpers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% writeMatch(+ResidentID, +ProgramID, +Stream)
%
% Print a successful resident-program match to file and console.

writeMatch(R,P,Stream) :-
    resident(R,name(FN,LN),_),
    program(P,Title,_,_),
    format(Stream,'~w,~w,~w,~w,~w~n',[LN,FN,R,P,Title]),
    format('~w,~w,~w,~w,~w~n',[LN,FN,R,P,Title]).

% writeUnmatched(+ResidentID, +Stream)
%
% Print a resident that didn’t match anywhere.

writeUnmatched(R,Stream) :-
    resident(R,name(FN,LN),_),
    format(Stream,'~w,~w,~w,XXX,NOT_MATCHED~n',[LN,FN,R]),
    format('~w,~w,~w,XXX,NOT_MATCHED~n',[LN,FN,R]).

% printResidents(+ResidentList, +MatchSet, +Stream, +Acc, -FinalCount)
%
% Prints all residents and counts how many went unmatched.

printResidents([],_,_,U,U).
printResidents([R|Rest],MS,Stream,Acc,Final) :-
    ( matched(R,P,MS) -> writeMatch(R,P,Stream), NewAcc=Acc
    ; writeUnmatched(R,Stream), NewAcc is Acc+1 ),
    printResidents(Rest,MS,Stream,NewAcc,Final).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Available positions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% availablePositions(+MatchSet, -TotalOpenPositions)
%
% Counts how many spots are left unfilled after matching.

availablePositions([],0).
availablePositions([match(P,Rs)|Rest],Total) :-
    program(P,_,Quota,_),
    length(Rs,L),
    Rem is Quota-L,
    availablePositions(Rest,T2),
    Total is Rem+T2.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Top-level predicate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% gale_shapley/0
%
% Runs the whole matching thing from start to finish.
% Steps:
% 1. Build rank table
% 2. Make empty matches for all programs
% 3. Sort residents
% 4. Run Gale-Shapley until stable
% 5. Print results and save to rp.txt

gale_shapley :-
    buildRankTable,                % precompute ranks
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