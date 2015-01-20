Datatype declaration
====================

> {-# LANGUAGE TypeOperators, TypeSynonymInstances, GADTs, PatternSynonyms #-}

> module Tactics.IData where

> import Control.Applicative
> import Control.Monad.Identity
> import Control.Monad.Except
> import Data.Traversable
> import Kit.MissingLibrary
> import Evidences.Tm
> import Evidences.Mangler
> import Evidences.Eval
> import Evidences.Operators
> import Evidences.DefinitionalEquality
> import NameSupply.NameSupplier
> import ProofState.Edition.Scope
> import ProofState.Edition.ProofState
> import ProofState.Edition.GetSet
> import ProofState.Edition.Navigation
> import ProofState.Edition.FakeRef
> import ProofState.Interface.ProofKit
> import ProofState.Interface.Module
> import ProofState.Interface.Definition
> import ProofState.Interface.Parameter
> import ProofState.Interface.Solving
> import ProofState.Interface.NameResolution
> import ProofState.Structure.Developments
> import Elaboration.Elaborator
> import DisplayLang.Name
> import DisplayLang.DisplayTm
> import Tactics.Data

> ielabCons :: String -> INTM -> (EXTM :=>: VAL) ->
>                [Elim VAL] -> (String , DInTmRN) ->
>                ProofState ( String          -- con name
>                           , EXTM            -- con ty
>                           , EXTM            -- con desc
>                           , [String]
>                           )
> ielabCons nom ty (indty :=>: indtyv) ps (s , t) = do
>   make (AnchTy s :<: ARR ty SET)
>   goIn
>   r <- lambdaParam nom
>   (tyi :=>: v) <- elabGive' t
>   (x,y) <- freshRef ("i" :<: indtyv)
>         (\i -> ity2desc indty r ps (NP i) (v $$ A (NP r)) >>=
>                  \(x,y) -> return ((L $ "i" :. (capM i 0 %% x))
>                           :? ARR (N indty)
>                                  (N (P idescREF :$ A (N indty))),y))
>   goOut
>   return (s, tyi, x, y)

> ity2desc :: EXTM -> REF -> [Elim VAL] -> VAL -> VAL -> ProofState (INTM,[String])
> ity2desc indty r ps ind (PI a b) = do
>             let anom = fortran b
>             a' <- bquoteHere a
>             if occurs r a'
>               then do
>                 a'' <- ity2h indty r ps a
>                 (b',us) <- freshRef (fortran b:<:a)
>                         (\s -> do (b',us) <- ity2desc indty r ps ind (b $$ A (NP s))
>                                   when (occurs s b') $
>                                     throwError (sErr "Bad dependency")
>                                   return (b',us))
>                 return (IPROD (TAG anom) a'' b',anom : us)
>               else do
>                 freshRef (anom :<: a)
>                  (\s -> ity2desc indty r ps ind (b $$ A (NP s)) >>=
>                           \(x,y) ->
>                             return (ISIGMA a' (L $ (fortran b) :. (capM s 0 %% x)),y))
> ity2desc indty r ps i (N (x :$ A i')) = do
>             b <- withNSupply (equal (SET :>: (N x, NP r $$$ ps)))
>             unless b $ throwError (sErr "C doesn't target T")
>             i'' <- bquoteHere i
>             i''' <- bquoteHere i'
>             return (ICONST (PRF (EQBLUE (N indty :>: i'') (N indty :>: i'''))),[])
> ity2desc _ _ _ _ _ = throwError (sErr "If you think this should work maybe you should have a chat with Dr Morris about it.")

> ity2h :: EXTM -> REF -> [Elim VAL] -> VAL -> ProofState INTM
> ity2h indty r ps (PI a b) = do
>   a' <- bquoteHere a
>   if occurs r a'
>     then throwError (sErr "Not strictly positive")
>     else do
>       b' <- freshRef (fortran b :<: a)
>               (\s -> ity2h indty r ps (b $$ A (NP s)) >>= \x ->
>                        pure (L $ (fortran b) :. (capM s 0 %% x) ))
>       return (IPI a' b')
> ity2h indty r ps (N (x :$ A i')) = do
>   b <- withNSupply (equal (SET :>: (N x, NP r $$$ ps)))
>   unless b $ throwError (sErr "Not SP")
>   i'' <- bquoteHere i'
>   return (IVAR i'')
> ity2h _ _ _ _ = throwError (sErr "If you think this should work maybe you should have a chat with Dr Morris about it.")

> imkAllowed :: (String, EXTM, INTM) -> [(String, EXTM, REF)] -> (INTM, INTM)
> imkAllowed (s, ty, i) = foldr mkAllowedHelp ((ARR (N ty) SET,
>                                              ALLOWEDCONS  (N ty)
>                                                           (LK SET)
>                                                           (N (P refl :$ A SET :$ A (ARR (N ty) SET)))
>                                                           i
>                                                           ALLOWEDEPSILON))
>     where mkAllowedHelp (x, ty, r) (allowingTy, allowedTy) =
>             let allowingTy' = L $ x :. (capM r 0 %% allowingTy) in
>             (PI (N ty) allowingTy',
>              ALLOWEDCONS (N ty) allowingTy' (N (P refl :$ A SET :$ A (PI (N ty) allowingTy'))) (NP r) allowedTy)

> ielabData :: String -> [ (String , DInTmRN) ] -> DInTmRN ->
>                        [ (String , DInTmRN) ] -> ProofState (EXTM :=>: VAL)
> ielabData nom pars indty scs = do
>   oldaus <- paramSpine <$> getInScope
>   makeModule DevelopData nom
>   goIn
>   pars' <- traverse (\(x,y) -> do
>     make (AnchParTy x :<: SET)
>     goIn
>     (yt :=>: yv) <- elabGive y
>     r <- assumeParam (x :<: (N yt :=>: yv))
>     return (x,yt,r)) pars
>   make (AnchIndTy :<: SET)
>   goIn
>   indty'@(indtye :=>: indtyv) <- elabGive indty
>   moduleToGoal (ARR (N indtye) SET)
>   cs <- traverse (ielabCons nom
>                   (foldr (\(x,s,r) t ->
>                             PI (N s) (L $ x :.
>                               (capM r 0 %% t))) (ARR (N indtye) SET) pars')
>                   indty' (map (\(_,_,r) -> A (NP r)) pars')) scs
>   make (AnchConNames :<: NP enumREF)
>   goIn
>   (e :=>: ev) <- giveOutBelow (foldr (\(t,_) e -> CONSE (TAG t) e) NILE scs)
>   make (AnchConDescs :<:
>           ARR (N indtye) (N (branchesOp
>                               :@ [ N e
>                                  , L $ K (N (P idescREF :$ A (N indtye)))
>                                  ])))
>   goIn
>   i <- lambdaParam "i"
>   (cs' :=>: _) <- giveOutBelow (foldr PAIR VOID (map (\(_,_,c,_) -> N (c :$ A (NP i))) cs))
>   make (AnchDataTy :<: ARR (N indtye) SET)
>   goIn
>   i <- lambdaParam "i"
>   let d = L $ "i" :.IFSIGMA (N e) (N (cs' :$ A (NV 0)))
>       (allowingTy, allowedBy)  =  imkAllowed ("i", indtye, NV 0) pars'
>                         -- XXX(joel) NV 0 refers to the .i. in the giveOut}
>       label                    =  ANCHOR (TAG nom) allowingTy allowedBy
>   (dty :=>: dtyv) <- giveOutBelow (IMU (Just (L $ "i" :. (let { i = 0 :: Int } in label))) (N indtye) d (NP i))

We specialise the induction operator to this datatype, ensuring the
label is assigned throughout, so the label will be preserved when
eliminating by induction.

This code attempts to find out if the definitions from
tests/TaggedInduction are in scope, if so you get nicer induction
principles (:

>   (do (icase,_,_) <- resolveHere [("TData",Rel 0),("tcase",Rel 0)]
>       makeModule DevelopOther "Case"
>       goIn
>       i <- assumeParam ("i" :<: (N indtye :=>: indtyv))
>       v <- assumeParam (comprefold (concat (map (\(_,_,_,c) -> c) cs))
>                         :<: (N (dty :$ A (NP i)) :=>: dtyv $$ A (NP i)))
>       let caseTm = P icase :$ A (N indtye)
>                            :$ A (PAIR (N e) (PAIR (N cs') VOID))
>                            :$ A (NP i) :$ A (NP v)
>       caseV :<: caseTy <- inferHere caseTm
>       caseTy' <- bquoteHere caseTy
>       moduleToGoal (isetLabel (L $ "i" :. (let { i = 0 :: Int } in label)) caseTy')
>       giveOutBelow (N caseTm)
>       return ()) `catchError` \_ -> return ()
>   (do (dind,_,_) <- resolveHere [("TData",Rel 0),("tind",Rel 0)]
>       makeModule DevelopOther "Ind"
>       goIn
>       i <- assumeParam ("i" :<: (N indtye :=>: indtyv))
>       v <- assumeParam (comprefold (concat (map (\(_,_,_,c) -> c) cs))
>                         :<: (N (dty :$ A (NP i)) :=>: dtyv $$ A (NP i)))
>       let dindT = P dind :$ A (N indtye)
>                          :$ A (PAIR (N e) (PAIR (N cs') VOID))
>                          :$ A (NP i) :$ A (NP v)
>       dindV :<: dindTy <- inferHere dindT
>       dindTy' <- bquoteHere dindTy
>       moduleToGoal (isetLabel (L $ "i" :. (let { i = 0 :: Int } in label)) dindTy')
>       giveOutBelow (N dindT)
>       return ()) `catchError` \_ ->
>     (do let indTm = P (lookupOpRef iinductionOp) :$ A (N indtye) :$ A d
>         indV :<: indTy <- inferHere indTm
>         indTy' <- bquoteHere indTy
>         make (AnchInd :<: isetLabel (L $ "i" :. (let { i = 0 :: Int } in label)) indTy')
>         goIn
>         giveOutBelow (N indTm)
>         return ())
>   giveOutBelow $ N dty

This is a hack, and should probably be replaced with a version that
tests for equality, so it doesn't catch the wrong `MU`s.

> isetLabel :: INTM -> INTM -> INTM
> isetLabel l (IMU Nothing ity tm i) = IMU (Just l) ity tm i
> isetLabel l (IMU (Just (LK (ANCHOR (TAG x) _ _))) ity tm i)
>               | x == "dataTy" = IMU (Just l) ity tm i
> isetLabel l (L (x :. t)) = L (x :. isetLabel l t)
> isetLabel l (L (K t)) = L (K (isetLabel l t))
> isetLabel l (C c) = C (fmap (isetLabel l) c)
> isetLabel l (N n) = N (isetLabelN l n)

> isetLabelN :: INTM -> EXTM -> EXTM
> isetLabelN l (P x) = P x
> isetLabelN l (V n) = V n
> isetLabelN l (op :@ as) = op :@ map (isetLabel l) as
> isetLabelN l (f :$ a) = isetLabelN l f :$ fmap (isetLabel l) a
> isetLabelN l (t :? ty) = isetLabel l t :? isetLabel l ty
