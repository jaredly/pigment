Record declaration
==================

> {-# LANGUAGE TypeOperators, TypeSynonymInstances, GADTs #-}
> module Tactics.Record where
> import Evidences.Tm
> import Evidences.Mangler
> import ProofState.Edition.ProofState
> import DisplayLang.Name

> elabRecord ::  String -> [(String , DInTmRN)] -> ProofState (EXTM :=>: VAL)
> elabRecord name fields = undefined -- XXX: not yet implemented
