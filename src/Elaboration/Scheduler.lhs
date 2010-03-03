\section{The Scheduler}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE GADTs, TypeOperators, TupleSections #-}

> module Elaboration.Scheduler where

> import NameSupply.NameSupply

> import Evidences.Tm
> import Evidences.Rules

> import Features.Features ()

> import ProofState.Developments
> import ProofState.ProofState
> import ProofState.ProofKit

> import DisplayLang.DisplayTm
> import DisplayLang.Naming

> import Tactics.Information

> import Elaboration.ElabMonad
> import Elaboration.MakeElab
> import Elaboration.Elaborator
> import Elaboration.Unification

> import Kit.BwdFwd
> import Kit.MissingLibrary

%endif

Handling elaboration essentially requires writing an operating system. Having
defined how to execute processes in section~\ref{sec:elaborator}, we now turn
our attention to process scheduling. The scheduler is called when an
elaboration process yields (either halting after solving its goal, halting
with an error, or suspending work until later). It searches downwards in the
proof state for unstable elaboration problems and executes any it finds.

When the scheduler is started, all problems before the working location should
be stable, but there may be unstable problems in the current location and below
it. The |startScheduler| command runs the scheduler from the top of the current
location, so it will stabilise the children and return to where it started.

> startScheduler :: ProofState ()
> startScheduler = cursorTop >> getMotherName >>= scheduler

In general, the scheduler might have to move non-locally (e.g. in order to solve
goals elsewhere in the proof state), so it keeps track of a target location to
return to.

> scheduler :: Name -> ProofState ()
> scheduler n = do
>     cs <- getDevCadets
>     case cs of

If we have no cadets to search, we check whether this is the target location:
if so, we stop, otherwise we go out and keep looking.

>         F0 -> do
>             mn <- getMotherName
>             if mn == n
>                 then return ()
>                 else case mn of
>                     []  -> error "scheduler: got lost!"
>                     _   -> goOutProperly >> scheduler n

Boys are simply ignored by the scheduler.

>         E _ _ (Boy _) _ :> _  -> cursorDown >> scheduler n

If we find a girl with an unstable elaboration problem attached, we have some
work to do. We enter the goal, remove the suspended problem and call |resume| to
actually resume elaboration. If elaboration succeeds, we solve the goal.
We then move the cursor to the top (since elaboration may have left some
suspended processes lying around that can now be resumed) and continue.

>         E ref _ (Girl _ (_, Suspended tt prob, _) _) _ :> _ | isUnstable prob -> do
>             cursorDown
>             goIn            
>             Suspended (ty :=>: tyv) prob <- getDevTip
>             putDevTip (Unknown (ty :=>: tyv))
>             mn <- getMotherName
>             schedTrace $ "scheduler: resuming elaboration on " ++ showName mn
>                 ++ ":  \n" ++ show prob
>             mtt <- resume (ty :=>: tyv) prob
>             case mtt of
>                 Just (tm :=>: _)  ->  give' tm
>                                   >>  schedTrace "scheduler: elaboration done."
>                 Nothing           ->  schedTrace "scheduler: elaboration suspended."
>             cursorTop
>             scheduler n

If we find a module or a girl without an unstable elaboration problem, we enter it
and search its children, starting from the top.

>         _ :> _ -> cursorDown >> goIn >> cursorTop >> scheduler n


Given a (potentially, but not necessarily, unstable) elaboration problem for the
current location, we can |resume| it to try to produce a term. If this suceeds,
the cursor will be in the same location, but if it fails (i.e.\ the problem has
been suspended) then the cursor could be anywhere earlier in the proof state.

> resume :: (INTM :=>: VAL) -> EProb -> ProofState (Maybe (INTM :=>: VAL))
> resume _ (ElabDone tt) = return . Just . maybeEval $ tt
> resume (ty :=>: tyv) (ElabProb tm) = 
>     return . ifSnd =<< runElab True (tyv :>: makeElab (Loc 0) (tyv :>: tm))
> resume (ty :=>: tyv) (ElabInferProb tm) =
>     return . ifSnd =<< runElab True (tyv :>: makeElabInfer (Loc 0) tm)
> resume (ty :=>: tyv) (WaitCan (tm :=>: Just (C v)) prob) =
>     resume (ty :=>: tyv) prob
> resume (ty :=>: tyv) (WaitCan (tm :=>: Nothing) prob) =
>     resume (ty :=>: tyv) (WaitCan (tm :=>: Just (evTm tm)) prob)
> resume _ prob@(WaitCan (tm :=>: _) _) = do
>     schedTrace $ "Suspended waiting for " ++ show tm ++ " to become canonical."
>     suspendMe prob
>     return Nothing
> resume _ (WaitSolve ref@(_ := HOLE _ :<: _) stt prob) = do
>     suspendMe prob
>     mn <- getMotherName
>     tm <- bquoteHere (valueOf . maybeEval $ stt) -- force definitional expansion
>     solveHole' ref [] tm -- takes us to who knows where
>     return Nothing
> resume tt (WaitSolve ref@(_ := DEFN tmv' :<: ty) stt prob) = do
>     eq <- withNSupply $ equal (ty :>: (valueOf . maybeEval $ stt , tmv'))
>     if eq
>         then  resume tt prob
>         else  throwError' $ err "resume: hole has been solved inconsistently! We should do something clever here."

> ifSnd :: (a, Bool) -> Maybe a
> ifSnd (a,  True)   = Just a
> ifSnd (_,  False)  = Nothing


Trace messages from the scheduler are essential for debugging but annoying
otherwise, so we can enable or disable them at compile time.

> schedTrace :: String -> ProofState ()
> schedTrace s = if schedTracing then proofTrace s else return ()

> schedTracing = False


The |elm| Cochon tactic elaborates a term, then starts the scheduler to
stabilise the proof state, and returns a pretty-printed representation of the
final type-term pair (using a quick hack).

> elmCT :: ExDTmRN -> ProofState String
> elmCT tm = do
>     suspend ("elab" :<: sigSetTM :=>: sigSetVAL) (ElabInferProb tm)
>     startScheduler
>     infoElaborate (DP [("elab", Rel 0)] ::$ [])

> import -> CochonTactics where
>   : unaryExCT "elm" elmCT "elm <term> - elaborate <term>, stabilise and print type-term pair."