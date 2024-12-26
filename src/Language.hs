module Language where

import Foundation

newtype Var = Var Text
  deriving stock (Eq)

data Expr
  = ExprVar Var
  | ExprIntLiteral Int
  | ExprAdd Expr Expr
  | ExprSub Expr Expr
  deriving stock (Eq)

data Statement
  = StatementAssign String Expr
  | StatementComment Text
  | StatementPrint Var
  deriving stock (Eq)

newtype Program = Program
  { _unProgram :: [Statement]
  }
  deriving stock (Eq)
