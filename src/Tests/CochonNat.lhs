%if False

> {-# OPTIONS_GHC -F -pgmF she #-}

> module Tests.CochonNat where

%endif

> import Control.Monad.State

> import Cochon
> import Developments
> import Elaborator
> import Nat
> import PrettyPrint
> import ProofState
> import Tm

> a = execStateT (do
>     make ("nat" :<: SET)
>     goIn
>     nat' <- bquoteHere nat
>     refNat <- elabGive nat'
>     
>     elabMake ("two" :<: refNat)
>     goIn
>     two' <- bquoteHere two
>     elabGive two'
>
>     elabMake ("four" :<: refNat)
>     goIn
>     four' <- bquoteHere four
>     elabGive four'
>
>     elabMake ("plus" :<: ARR refNat (ARR refNat refNat))
>     goIn
>     plus' <- bquoteHere plus
>     elabGive plus'
>   ) emptyContext 

> Right loc = a

> Right (s, _) = runStateT prettyProofState loc

> main = cochon loc