Fake references
===============

> {-# LANGUAGE FlexibleInstances, TypeOperators, TypeSynonymInstances,
>              GADTs, RankNTypes #-}

> module ProofState.Edition.FakeRef where

> import ProofState.Edition.ProofContext
> import ProofState.Edition.Scope
> import ProofState.Edition.ProofState
> import ProofState.Edition.GetSet
> import Evidences.Tm
> import Evidences.Eval

The `getFakeCurrentEntry` command returns a neutral application of a fake
reference that represents the current entry of the current location. Note that
its type is lambda-lifted over its parameters in global scope, but it is then
applied to them (as shared parameters).


> getFakeRef :: ProofState REF
> getFakeRef = do
>    CDefinition _  (cEntryName := HOLE _ :<: ty) _ _ _ _ <- getCurrentEntry
>    return $ cEntryName := FAKE :<: ty


> getFakeCurrentEntry :: ProofState (EXTM :=>: VAL)
> getFakeCurrentEntry = do
>    r <- getFakeRef
>    inScope <- getInScope
>    let tm = P r $:$ (paramSpine inScope)
>    return $ tm :=>: evTm tm
