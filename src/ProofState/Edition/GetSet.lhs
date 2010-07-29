\section{The Get Set}


%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE FlexibleInstances, TypeOperators, TypeSynonymInstances,
>              GADTs, RankNTypes #-}

> module ProofState.Edition.GetSet where

> import Control.Monad.State
> import Data.Foldable
> import Debug.Trace

> import Kit.BwdFwd
> import Kit.MissingLibrary

> import NameSupply.NameSupply

> -- XXX: bug "fix" of the dependency graph:
> import DisplayLang.DisplayTm
> import DisplayLang.Scheme
> import DisplayLang.Name

> import ProofState.Structure.Developments

> import ProofState.Edition.News
> import ProofState.Edition.ProofContext
> import ProofState.Edition.ProofState
> import ProofState.Edition.Entries
> import ProofState.Edition.Scope

> import Evidences.Rules
> import Evidences.Tm

%endif

We provide various functions to get information from the proof state and store
updated information, providing a friendlier interface than |get| and |put|.

\question{That would be great to have an illustration of the behavior
          of each of these functions on a development.}

\subsubsection{Getters}

> getInScope :: ProofStateT e Entries
> getInScope = gets inScope

> getAunclesToImpl :: ProofStateT e [REF :<: INTM]
> getAunclesToImpl = gets definitionsToImpl

> getDev :: ProofStateT e (Dev Bwd)
> getDev = gets pcAboveCursor

> getDevCadets :: ProofStateT e (Fwd (Entry Bwd))
> getDevCadets = gets pcBelowCursor

> getDevEntries :: ProofStateT e Entries
> getDevEntries = do
>     dev <- getDev
>     return $ devEntries dev

> getDevEntry :: ProofStateT e (Entry Bwd)
> getDevEntry = do
>     _ :< e <- getDevEntries
>     return e

> getDevNSupply :: ProofStateT e NameSupply
> getDevNSupply = do
>     dev <- getDev
>     return $ devNSupply dev

> getDevTip :: ProofStateT e Tip
> getDevTip = do
>     dev <- getDev
>     return $ devTip dev

> getGoal :: String -> ProofStateT e (INTM :=>: TY)
> getGoal s = do
>     tip <- getDevTip
>     case tip of
>       Unknown (ty :=>: tyTy) -> return (ty :=>: tyTy)
>       Defined _ (ty :=>: tyTy) -> return (ty :=>: tyTy)
>       _ -> throwError'  $ err "getGoal: fail to match a goal in " 
>                         ++ err s

> getGreatAuncles :: ProofStateT e Entries
> getGreatAuncles = gets globalScope

> getBoys :: ProofStateT e [REF]
> getBoys = do  
>     inScope <- getInScope
>     return $ foldMap boy inScope
>    where boy (EPARAM r _ _ _)  = [r]
>          boy _ = []

> getBoysBwd :: ProofStateT e (Bwd REF)
> getBoysBwd = do  
>     inScope <- getInScope
>     return $ foldMap boy inScope 
>    where boy (EPARAM r _ _ _)  = (B0 :< r)
>          boy _ = B0

> getHoleGoal :: ProofStateT e (INTM :=>: TY)
> getHoleGoal = do
>     CDefinition _ (_ := HOLE _ :<: _) _ _ <- getMother
>     getGoal "getHoleGoal"

> getHoleKind :: ProofStateT e HKind
> getHoleKind = do
>     CDefinition _ (_ := HOLE hk :<: _) _ _ <- getMother
>     return hk

> getLayer :: ProofStateT e Layer
> getLayer = do
>     ls :< l <- getLayers
>     return l

> getLayers :: ProofStateT e (Bwd Layer)
> getLayers = gets pcLayers

> getMother :: ProofStateT e CurrentEntry
> getMother = do
>     ls <- getLayers
>     case ls of
>         _ :< l  -> return (currentEntry l)
>         B0      -> return (CModule []) 

> getMotherDefinition :: ProofStateT e (EXTM :=>: VAL)
> getMotherDefinition = do
>     CDefinition _ ref _ _ <- getMother
>     aus <- getGreatAuncles
>     return (applyAuncles ref aus)

> getMotherEntry :: ProofStateT e (Entry Bwd)
> getMotherEntry = do
>     m <- getMother
>     Dev es tip root ss <- getDev
>     cadets <- getDevCadets
>     let dev = Dev (es <>< cadets) tip root ss
>     case m of
>         CDefinition dkind ref xn ty -> return (EDEF ref xn dkind dev ty)
>         CModule n -> return (EModule n dev)

> getMotherName :: ProofStateT e Name
> getMotherName = do
>     ls <- getLayers
>     case ls of
>         (_ :< Layer{currentEntry=m}) -> return (currentEntryName m)
>         B0 -> return []


\subsubsection{Putters}


> insertCadet :: NewsBulletin -> ProofStateT e ()
> insertCadet news = do
>     l <- getLayer
>     replaceLayer l{belowEntries = NF (Left news :> unNF (belowEntries l))}
>     return ()

> putDev :: Dev Bwd -> ProofStateT e ()
> putDev dev = do
>     pc <- get
>     put pc{pcAboveCursor=dev}

> putDevCadet :: Entry Bwd -> ProofStateT e ()
> putDevCadet e = do
>     cadets <- getDevCadets
>     putDevCadets (e :> cadets)
>     return ()

> putDevCadets :: Fwd (Entry Bwd) -> ProofStateT e (Fwd (Entry Bwd))
> putDevCadets cadets = do
>     pc <- get
>     put pc{pcBelowCursor=cadets}
>     return (pcBelowCursor pc)

> putDevEntry :: Entry Bwd -> ProofStateT e ()
> putDevEntry e = do
>     dev <- getDev
>     putDev dev{devEntries = devEntries dev :< e}

> putDevEntries :: Entries -> ProofStateT e ()
> putDevEntries es = do
>     dev <- getDev
>     putDev dev{devEntries = es}

> putDevNSupply :: NameSupply -> ProofStateT e ()
> putDevNSupply ns = do
>     dev <- getDev
>     putDev dev{devNSupply = ns}

> putDevSuspendState :: SuspendState -> ProofStateT e ()
> putDevSuspendState ss = do
>     dev <- getDev
>     putDev dev{devSuspendState = ss}

> putDevTip :: Tip -> ProofStateT e ()
> putDevTip tip = do
>     dev <- getDev
>     putDev dev{devTip = tip}

> putHoleKind :: HKind -> ProofStateT e ()
> putHoleKind hk = do
>     CDefinition kind (name := HOLE _ :<: ty) xn tm <- getMother
>     putMother $ CDefinition kind (name := HOLE hk :<: ty) xn tm

> putLayer :: Layer -> ProofStateT e ()
> putLayer l = do
>     pc@PC{pcLayers=ls} <- get
>     put pc{pcLayers=ls :< l}

> putLayers :: Bwd Layer -> ProofStateT e ()
> putLayers ls = do
>     pc <- get
>     put pc{pcLayers=ls}

> putMother :: CurrentEntry -> ProofStateT e ()
> putMother m = do
>     l <- getLayer
>     _ <- replaceLayer l{currentEntry=m}
>     return ()

> putMotherEntry :: Entry Bwd -> ProofStateT e ()
> putMotherEntry (EDEF ref xn dkind dev ty) = do
>     l <- getLayer
>     replaceLayer (l{currentEntry=CDefinition dkind ref xn ty})
>     putDev dev
> putMotherEntry (EModule [] dev) = putDev dev
> putMotherEntry (EModule n dev) = do
>     l <- getLayer
>     replaceLayer (l{currentEntry=CModule n})
>     putDev dev

> putMotherScheme :: Scheme INTM -> ProofState ()
> putMotherScheme sch = do
>     CDefinition _ ref xn ty <- getMother
>     putMother (CDefinition (PROG sch) ref xn ty)

\subsubsection{Removers}


> removeDevEntry :: ProofStateT e (Maybe (Entry Bwd))
> removeDevEntry = do
>     es <- getDevEntries
>     case es of
>       B0 -> return Nothing
>       (es' :< e) -> do
>         putDevEntries es'
>         return (Just e)

> removeLayer :: ProofStateT e Layer
> removeLayer = do
>     pc@PC{pcLayers=ls :< l} <- get
>     put pc{pcLayers=ls}
>     return l

\subsubsection{Replacers}

> replaceDev :: Dev Bwd -> ProofStateT e (Dev Bwd)
> replaceDev dev = do
>     pc <- get
>     put pc{pcAboveCursor=dev}
>     return (pcAboveCursor pc)

> replaceDevEntries :: Entries -> ProofStateT e Entries
> replaceDevEntries es = do
>     es' <- getDevEntries
>     putDevEntries es
>     return es'

> replaceLayer :: Layer -> ProofStateT e Layer
> replaceLayer l = do
>     (ls :< l') <- getLayers
>     putLayers (ls :< l)
>     return l'


When the current location or one of its children has suspended, we need to
update the outer layers.

> grandmotherSuspend :: SuspendState -> ProofState ()
> grandmotherSuspend ss = getLayers >>= putLayers . help ss
>   where
>     help :: SuspendState -> Bwd Layer -> Bwd Layer
>     help ss B0 = B0
>     help ss (ls :< l) = help ss' ls :< l{laySuspendState = ss'}
>       where ss' = min ss (laySuspendState l)