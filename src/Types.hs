{-# LANGUAGE DeriveFunctor     #-}
{-# LANGUAGE DeriveFoldable    #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE TemplateHaskell   #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DeriveAnyClass   #-}

module Types where

import           Standard
import           Graphics.X11.Types
import           Graphics.X11.Xlib.Extras
import           Graphics.X11.Xlib.Types
import           Text.Show.Deriving
import           Data.Eq.Deriving
import           FocusList
import           Dhall (Interpret)
import qualified SDL (Window)

-- | A simple rectangle
data Rect = Rect
  { x :: Position
  , y :: Position
  , w :: Dimension
  , h :: Dimension
  }
  deriving (Show, Eq)

-- | A simple rectangle
data RRect = RRect
  { xp :: Double
  , yp :: Double
  , wp :: Double
  , hp :: Double
  }
  deriving (Show, Eq)

data Plane = Plane
  { rect :: Rect
  , depth :: Int
  }
  deriving Show

data Sized a = Sized {getSize :: Double, getItem :: a}
  deriving (Show, Functor, Foldable, Traversable)

toTup :: ((Double, a) -> (c, b)) -> Sized a -> (c, b)
toTup f (Sized d a) = f (d, a)

asTup :: ((Double, a) -> (Double, b)) -> Sized a -> Sized b
asTup f (Sized d a) = let (newD, b) = f (d, a) in Sized newD b

instance Eq a => Eq (Sized a) where
  (Sized _ a) == (Sized _ b) = a == b
deriveShow1 ''Sized
deriveEq1 ''Sized

data BottomOrTop a = Bottom a | Top (RRect, a)
  deriving (Eq, Show, Functor, Foldable, Traversable)
deriveShow1 ''BottomOrTop
deriveEq1 ''BottomOrTop
instance Comonad BottomOrTop where
  extract (Bottom a) = a
  extract (Top (_,a)) = a
  duplicate = Bottom


getEither :: BottomOrTop a -> a
getEither (Bottom a) = a
getEither (Top (_, a)) = a

data ChildParent = ChildParent Window Window
  deriving Show

inChildParent :: Window -> ChildParent -> Bool
inChildParent w (ChildParent ww ww') = w == ww || w == ww'

instance Eq ChildParent where
  (ChildParent a b) == (ChildParent a' b') = a == a' || b == b'

data Tiler a
  = Horiz (FocusedList (Sized a))
  | Floating (NonEmpty (BottomOrTop a))
  | Reflect a
  | FocusFull a
  | Wrap ChildParent
  | InputController Int (Maybe a)
  | Monitor Int (Maybe a)
  deriving (Eq, Show, Functor, Foldable, Traversable)
instance MonoFoldable (Tiler a)
deriveShow1 ''Tiler
deriveEq1 ''Tiler

type instance Element (Tiler a) = a

makeBaseFunctor ''Tiler

newtype MaybeTiler a = Maybe (Tiler a)

-- | Convenience type for keyEvents
type KeyTrigger = (KeyCode, Mode, Actions)
                                   
-- Create a junk instantiations for auto-deriving later
instance Eq Event where
  (==) = error "Don't compare XorgEvents"


data Insertable
  = Horizontal
  | Hovering
  | Rotate
  | FullScreen
  deriving (Generic, Show, Eq, Interpret)

-- | Actions/events to be performed
data Action
  = Insert Insertable
  -- | ChangeLayoutTo Insertable
  | ChangeNamed String
  | ChangePostprocessor KeyStatus
  | Move Direction
  | RunCommand String
  | ChangeModeTo Mode
  | ShowWindow String
  | HideWindow String
  | ZoomInInput
  | ZoomOutInput
  | ZoomInMonitor
  | ZoomOutMonitor
  | PopTiler
  | PushTiler
  | MakeSpecial
  | KillActive
  | ExitNow
  | KeyboardEvent KeyTrigger Bool -- TODO use something other than Bool for keyPressed
  | XorgEvent Event
  deriving Show

-- | A series of commands to be executed
type Actions = [Action]

-- | Modes similar to modes in vim
data Mode = NewMode { modeName     :: Text
                    , introActions :: Actions
                    , exitActions  :: Actions
                    , hasButtons :: Bool
                    , hasBorders :: Bool
                    }
instance Eq Mode where
  n1 == n2 = modeName n1 == modeName n2

instance Show Mode where
  show (NewMode t _ _ _ _) = show t

-- | The user provided configuration.
data Conf = Conf { keyBindings  :: [KeyTrigger]
                 , definedModes :: [Mode]
                 }

data KeyStatus = New Mode KeyTrigger | Temp Mode KeyTrigger | Default

instance Show KeyStatus where
  show _ = "Key status"

type KeyPostprocessor r = Mode -> KeyTrigger -> Action -> Actions

type Borders = (SDL.Window, SDL.Window, SDL.Window, SDL.Window)

data MouseButtons = LeftButton (Int, Int) | RightButton (Int, Int) | None
  deriving Show

-- TODO should this all be here
type Reparenter = Maybe (Tiler (Fix Tiler)) -> Maybe (Fix Tiler)
type Unparented = Maybe (Fix Tiler)
data TreeCombo = Neither | Unmovable | Movable (Reparenter, Unparented) | Both

getMovable :: TreeCombo -> Maybe (Reparenter, Unparented)
getMovable (Movable m) = Just m
getMovable _ = Nothing

isUnmovable :: TreeCombo -> Bool
isUnmovable Unmovable = True
isUnmovable _ = False

isBoth :: TreeCombo -> Bool
isBoth Both = True
isBoth _ = False

instance Semigroup TreeCombo where
  Neither <> a = a
  a <> Neither = a
  Both <> _ = Both
  _ <> Both = Both
  _ <> _ = Both
  
instance Monoid TreeCombo where
  mempty = Neither
instance Show TreeCombo where
  show Both = "Both"
  show Neither = "Neither"
  show Unmovable = "Unmovable"
  show (Movable _) = "Movable"
-- data TreeCombo = TreeCombo { hasMovable :: Bool
--                            , hasMonitor :: Bool
--                            , hasWin :: Bool
--                            }
--   deriving (Eq, Show)

-- withController :: TreeCombo
-- withController = TreeCombo True False False
-- withMonitor :: TreeCombo
-- withMonitor = TreeCombo False True False
-- withWin :: TreeCombo
-- withWin = TreeCombo False False True

-- instance Semigroup TreeCombo where
--   TreeCombo a b c <> TreeCombo a2 b2 c2 = TreeCombo (a&&a2) (b&&b2) (c&&c2)

-- instance Monoid TreeCombo where
--   mempty = TreeCombo False False False

