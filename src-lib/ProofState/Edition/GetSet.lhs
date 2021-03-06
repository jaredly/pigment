The Get Set
===========

> {-# LANGUAGE FlexibleInstances, TypeOperators, TypeSynonymInstances,
>              GADTs, RankNTypes, ScopedTypeVariables #-}

> module ProofState.Edition.GetSet where

> import Control.Monad.State

> import Control.Error

> import Kit.BwdFwd
> import Kit.MissingLibrary
> import NameSupply.NameSupply
> import DisplayLang.Scheme
> import ProofState.Structure.Developments
> import ProofState.Edition.News
> import ProofState.Edition.ProofContext
> import ProofState.Edition.ProofState
> import ProofState.Edition.Entries
> import ProofState.Edition.Scope
> import Evidences.Tm

We provide various functions to get information from the proof state and
store updated information, providing a friendlier interface than `get`
and `put`. The rule of thumb for naming these functions is to prefix the
name of a field by the action (`get`, `put`, `remove`, or `replace`).

Getters
-------

Getting in `ProofContext`

> getLayers :: ProofStateT e (Bwd Layer)
> getLayers = gets pcLayers

> getAboveCursor :: ProofStateT e (Dev Bwd)
> getAboveCursor = gets pcAboveCursor

> getBelowCursor :: ProofStateT e (Fwd (Entry Bwd))
> getBelowCursor = gets pcBelowCursor

And some specialized versions:

> getLayer :: forall e. ProofStateT e Layer
> getLayer = do
>     layers <- getLayers
>     case layers of
>         _ :< l -> return l
>         _ -> throwStack (errMsgStack "couldn't get layer" :: StackError e)

throwErrMsg :: ErrorStack m VAL => String -> m a

Getting in `AboveCursor`

> getEntriesAbove :: ProofStateT e Entries
> getEntriesAbove = do
>     dev <- getAboveCursor
>     return $ devEntries dev

> getDevNSupply :: ProofStateT e NameSupply
> getDevNSupply = do
>     dev <- getAboveCursor
>     return $ devNSupply dev

> getDevTip :: ProofStateT e Tip
> getDevTip = do
>     dev <- getAboveCursor
>     return $ devTip dev

And some specialized versions:

> getEntryAbove :: ProofStateT e (Entry Bwd)
> getEntryAbove = do
>     _ :< e <- getEntriesAbove -- XXX this errors on "done"
>     return e

> getGoal :: forall e. String -> ProofStateT e (INTM :=>: TY)
> getGoal s = do
>     tip <- getDevTip
>     case tip of
>       Unknown (ty :=>: tyTy) -> return (ty :=>: tyTy)
>       Defined _ (ty :=>: tyTy) -> return (ty :=>: tyTy)
>       _ ->
>           let stack :: StackError e
>               stack = stackItem
>                   [ errMsg "getGoal: fail to match a goal in "
>                   , errMsg s
>                   ]
>           in throwStack stack

> withGoal :: (VAL -> ProofState ()) -> ProofState ()
> withGoal f = do
>   (_ :=>: goal) <- getGoal "withGoal"
>   f goal

Getting in the `Layers`

> getCurrentEntry :: ProofStateT e CurrentEntry
> getCurrentEntry = do
>     ls <- getLayers
>     case ls of
>         _ :< l  -> return (currentEntry l)
>         B0      -> return (CModule [] EmptyModule emptyMetadata)

Getting in the `CurrentEntry`

> getCurrentName :: ProofStateT e Name
> getCurrentName = do
>     cEntry <-  getCurrentEntry
>     case cEntry of
>       CModule [] _ _ -> return []
>       _              -> return $ currentEntryName cEntry

> getCurrentDefinition :: ProofStateT e (EXTM :=>: VAL)
> getCurrentDefinition = do
>     CDefinition _ ref _ _ _ _ <- getCurrentEntry
>     scope <- getGlobalScope
>     return (applySpine ref scope)

Getting in the `HOLE`

> getHoleGoal :: forall e. ProofStateT e (INTM :=>: TY)
> getHoleGoal = do
>     x <- getCurrentEntry
>     case x of -- TODO(joel) do this properly with error machinery
>         CDefinition _ (_ := HOLE _ :<: _) _ _ _ _ -> getGoal "getHoleGoal"
>         CModule _ _ _ -> throwStack
>             (errMsgStack "got a module" :: StackError e)
>         CDefinition _ _ _ _ _ _ -> throwStack
>             (errMsgStack "got a non-hole definition" :: StackError e)

> getHoleKind :: ProofStateT e HKind
> getHoleKind = do
>     CDefinition _ (_ := HOLE hk :<: _) _ _ _ _ <- getCurrentEntry
>     return hk

Getting the Scopes

> getInScope :: ProofStateT e Entries
> getInScope = gets inScope

> getDefinitionsToImpl :: ProofStateT e [REF :<: INTM]
> getDefinitionsToImpl = gets definitionsToImpl

> getGlobalScope :: ProofStateT e Entries
> getGlobalScope = gets globalScope

> getParamsInScope :: ProofStateT e [REF]
> getParamsInScope = do
>     inScope <- getInScope
>     return $ paramREFs inScope

Putters
-------

Putting in `ProofContext`

> putLayers :: Bwd Layer -> ProofStateT e ()
> putLayers ls = do
>     pc <- get
>     put pc{pcLayers=ls}

> putAboveCursor :: Dev Bwd -> ProofStateT e ()
> putAboveCursor dev = do
>     replaceAboveCursor dev
>     return ()

> putBelowCursor :: Fwd (Entry Bwd) -> ProofStateT e (Fwd (Entry Bwd))
> putBelowCursor below = do
>     pc <- get
>     put pc{pcBelowCursor=below}
>     return (pcBelowCursor pc)

And some specialized versions:

> putLayer :: Layer -> ProofStateT e ()
> putLayer l = do
>     pc@PC{pcLayers=ls} <- get
>     put pc{pcLayers=ls :< l}

> putEntryBelowCursor :: Entry Bwd -> ProofStateT e ()
> putEntryBelowCursor e = do
>     below <- getBelowCursor
>     putBelowCursor (e :> below)
>     return ()

Putting in `AboveCursor`

> putEntriesAbove :: Entries -> ProofStateT e ()
> putEntriesAbove es = do
>     replaceEntriesAbove es
>     return ()

> putDevNSupply :: NameSupply -> ProofStateT e ()
> putDevNSupply ns = do
>     dev <- getAboveCursor
>     putAboveCursor dev{devNSupply = ns}

> putDevSuspendState :: SuspendState -> ProofStateT e ()
> putDevSuspendState ss = do
>     dev <- getAboveCursor
>     putAboveCursor dev{devSuspendState = ss}

> putDevTip :: Tip -> ProofStateT e ()
> putDevTip tip = do
>     dev <- getAboveCursor
>     putAboveCursor dev{devTip = tip}

And some specialized versions:

> putEntryAbove :: Entry Bwd -> ProofStateT e ()
> putEntryAbove e = do
>     dev <- getAboveCursor
>     putAboveCursor dev{devEntries = devEntries dev :< e}

Putting in the `Layers`

> putCurrentEntry :: CurrentEntry -> ProofStateT e ()
> putCurrentEntry m = do
>     l <- getLayer
>     _ <- replaceLayer l{currentEntry=m}
>     return ()

> putNewsBelow :: NewsBulletin -> ProofStateT e ()
> putNewsBelow news = do
>     l <- getLayer
>     replaceLayer l{belowEntries = NF (Left news :> unNF (belowEntries l))}
>     return ()

Putting in the `CurrentEntry`

Putting in the `PROG`

> putCurrentScheme :: Scheme INTM -> ProofState ()
> putCurrentScheme sch = do
>     CDefinition _ ref xn ty a meta <- getCurrentEntry
>     putCurrentEntry $ CDefinition (PROG sch) ref xn ty a meta

Putting in the `HOLE`

> putHoleKind :: HKind -> ProofStateT e ()
> putHoleKind hk = do
>     CDefinition kind (name := HOLE _ :<: ty) xn tm a meta <- getCurrentEntry
>     putCurrentEntry $ CDefinition kind (name := HOLE hk :<: ty) xn tm a meta

Removers
--------

Remove in `ProofContext`

> removeLayer :: forall e. ProofStateT e Layer
> removeLayer = do
>     pc <- get
>     case pc of
>         PC{pcLayers=ls :< l} -> put pc{pcLayers=ls} >> return l
>         _ -> throwStack (errMsgStack "couldn't remove layer" :: StackError e)

Removing in `AboveEntries`

> removeEntryAbove :: ProofStateT e (Maybe (Entry Bwd))
> removeEntryAbove = do
>     es <- getEntriesAbove
>     case es of
>       B0 -> return Nothing
>       (es' :< e) -> do
>         putEntriesAbove es'
>         return $ Just e

Replacers
---------

Replacing into `ProofContext`

> replaceAboveCursor :: Dev Bwd -> ProofStateT e (Dev Bwd)
> replaceAboveCursor dev = do
>     pc <- get
>     put pc{pcAboveCursor=dev}
>     return (pcAboveCursor pc)

And some specialized version:

> replaceLayer :: Layer -> ProofStateT e Layer
> replaceLayer l = do
>     (ls :< l') <- getLayers
>     putLayers (ls :< l)
>     return l'

Replacing in `AboveCursor`

> replaceEntriesAbove :: Entries -> ProofStateT e Entries
> replaceEntriesAbove es = do
>     dev <- getAboveCursor
>     putAboveCursor dev{devEntries = es}
>     return (devEntries dev)
