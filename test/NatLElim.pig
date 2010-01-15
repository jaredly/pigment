make NatD := con ['arg (Enum ['zero 'suc]) [ (con ['done]) (con ['ind1 con ['done]]) ] ] : Desc ;
make Nat := (Mu NatD) : Set ;
make suc := (\ x -> con ['suc x]) : Nat -> Nat ;
make zero := [] : Nat ;
make one := (suc zero) : Nat ;
make two := (suc one) : Nat ;
make add := ? : Nat -> Nat -> Nat ;
make add : (x : Nat) -> (y : Nat) -> < add x y : Nat > ;
lambda x ;
lambda y ;
elim elimOp NatD x ;
give con ? ;
give [ ? ? ] ;
give con con ? ;
give return y ;
lambda r ;
give con ? ;
lambda xy ;
give con ? ;
give return (suc ((xy) call))  ;
root ;
elab add two two 