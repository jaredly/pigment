Making Parameters
=================

> {-# LANGUAGE FlexibleInstances, TypeOperators, TypeSynonymInstances,
>              GADTs, RankNTypes, PatternSynonyms #-}

> module ProofState.Interface.Parameter where

> import Control.Error

> import Kit.MissingLibrary
> import NameSupply.NameSupplier
> import ProofState.Structure.Developments
> import ProofState.Edition.ProofState
> import ProofState.Edition.GetSet
> import ProofState.Interface.ProofKit
> import Evidences.Tm

`\`-abstraction
---------------

When working at solving a goal, we might be able to introduce an hypothesis.
For instance, if the goal type is `Nat -> Nat -> Nat`, we can introduce two
hypotheses `x` and `y` Further, the type of the goal governs the kind of the
parameter (a lambda, or a forall) and its type. This automation is implemented
by `lambdaParam` that lets you introduce a parameter above the cursor while
working on a goal.

> lambdaParam :: String -> ProofState REF
> lambdaParam x = do
>     tip <- getDevTip
>     case tip of
>       Unknown (pi :=>: ty) ->
>         -- Working at solving a goal
>         case lambdable ty of
>         Just (paramKind, s, t) ->
>             -- Where can rightfully introduce a lambda
>             freshRef (x :<: s) $ \ref -> do
>               -- Insert the parameter above the cursor
>               putEntryAbove $ EPARAM ref (mkLastName ref) paramKind s
>                                      AnchNo emptyMetadata
>               -- Update the Tip
>               let tipTy = t $ pval ref
>               putDevTip (Unknown (tipTy :=>: tipTy))
>               -- Return the reference to the parameter
>               return ref
>         _  -> throwDTmStr "lambdaParam: goal is not a pi-type or all-proof."
>       _    -> throwDTmStr "lambdaParam: only possible for incomplete goals."

Assumptions
-----------

With `lambdaParam`, we can introduce parameters under a proof goal.
However, when working under a module, we would like to be able to
introduce hypothesis of some type. This corresponds to some kind of
"Assume" mechanism, where we assume the existence of an object of the
provided type under the given module.

> assumeParam :: (String :<: (INTM :=>: TY)) -> ProofState REF
> assumeParam (x :<: (tyTm :=>: ty))  = do
>     tip <- getDevTip
>     case tip of
>       Module ->
>         -- Working under a module
>         freshRef (x :<: ty) $ \ref -> do
>           -- Simply make the reference
>           putEntryAbove $ EPARAM ref (mkLastName ref) ParamLam tyTm AnchNo
>                                  emptyMetadata
>           return ref
>       _    -> throwDTmStr "assumeParam: only possible for modules."

`Pi`-abstraction
----------------

When working at defining a type (an object in `Set`), we can freely
introduce `Pi`-abstractions. This is precisely what `piParam` let us do.

> piParam :: (String :<: INTM) -> ProofState REF
> piParam (s :<: ty) = do
>   ttv <- checkHere $ SET :>: ty
>   piParamUnsafe $ s :<: ttv

The variant `piParamUnsafe` will not check that the proposed type is
indeed a type, so it requires further attention.

> piParamUnsafe :: (String :<: (INTM :=>: TY)) -> ProofState REF
> piParamUnsafe (s :<: (tyTm :=>: ty)) = do
>     tip <- getDevTip
>     case tip of
>         Unknown (_ :=>: SET) ->
>           -- Working on a goal of type `Set`
>           freshRef (s :<: ty) $ \ref -> do
>             -- Simply introduce the parameter
>             putEntryAbove $ EPARAM ref (mkLastName ref) ParamPi tyTm AnchNo
>                                    emptyMetadata
>             return ref
>         Unknown _  -> throwDTmStr "piParam: goal is not of type SET."
>         _ -> throwDTmStr "piParam: only possible for incomplete goals."
