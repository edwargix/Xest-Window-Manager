{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE Strict #-}

module Base.DoAll
  ( module Base.Helpers
  , module Base.Other
  , module Base.Mover
  , module Base.Property
  , module Base.Minimizer
  , module Base.Executor
  , module Base.Global
  , module Base.EventFlags
  , module Base.Colorer
  , module Base.DoAll
  )
where

import           Standard
import           Polysemy
import           Polysemy.State
import           Polysemy.Input
import           Polysemy.Several
import           Graphics.X11.Xlib.Types
import           Graphics.X11.Xinerama
import           Graphics.X11.Types
import qualified Data.Set                      as S
import qualified Data.Map                      as M
import qualified SDL
import qualified SDL.Font                      as Font
import           Base.Helpers
import           Base.Other
import           Base.Mover
import           Base.Property
import           Base.Minimizer
import           Base.Executor
import           Base.Global
import           Base.Colorer
import           Base.EventFlags
import           Tiler.TilerTypes
import           Config
import           Actions.ActionTypes

-- There's a lot of effects here. This type has them all!
type DoAll r
  =  ( Members
        ( States
            '[Tiler, KeyStatus, Mode, Set Window, [SubTiler], MouseButtons, Maybe
              Font.Font, Bool, Map Window XRect, Maybe (), Conf, ActiveScreen, Screens]
        )
        r
    , Members
        ( Inputs
            '[Conf, Window, Borders, Display, XRect, (Int32, Int32), MouseButtons, [ XineramaScreenInfo
            ], Screens, [XRect], NewBorders]
        )
        r
    , Members
        '[Mover, Property, Minimizer, Executor, GlobalX, Colorer, EventFlags, Embed
          IO]
        r
    )
  => Sem r ()

-- Want to do everything in IO? Use this!
doAll
  :: Screens
  -> Conf
  -> Mode
  -> Display
  -> Window
  -> _ -- The super long Sem list which GHC can figure out on its own
  -> IO ()
doAll t c m d w =
  void
    . runM
    . runStates
        (   m
        ::: S.empty @RootWindow
        ::: Default
        ::: t
        ::: [] @SubTiler
        ::: None
        ::: Nothing
        ::: False
        ::: M.empty @String
        ::: M.empty @Atom @[Int]
        ::: FocusedCache 0
        ::: M.empty @SDL.Window
        ::: M.empty @Window @XRect
        ::: [] @Window
        ::: Just ()
        ::: c
        ::: (0 :: ActiveScreen)
        ::: HNil
        )
    . runInputs (w ::: d ::: HNil)
    . stateToInput @Screens
    . smartBorders
    . runNewBorders
    . runGetScreens
    . listOfScreens
    . indexedState
    . runInputScreen
    . stateToInput @Conf
    . runGetButtons
    . runGetPointer
    . runProperty
    . runEventFlags
    . runGlobalX
    . runMinimizer
    . runMover
    . runExecutor
    . runColorer
 where


  -- Get the screens from Xinerama
  runInputScreen
    :: Members (States '[ActiveScreen, Screens]) r
    => Sem (Input XRect ': r) a
    -> Sem r a
  runInputScreen = runInputSem $ do
    activeScreen <- get @ActiveScreen
    gets @Screens $ screenSize . fromMaybe screenError . lookup activeScreen

  listOfScreens
    :: Member (Input Screens) r => Sem (Input [XRect] ': r) a -> Sem r a
  listOfScreens = interpret $ \case
    Input -> toList . fmap screenSize <$> input @Screens
  smartBorders
    :: Members '[Input Screens, State ActiveScreen] r
    => Sem (Input Borders ': r) a
    -> Sem r a
  smartBorders = interpret $ \case
    Input ->
      get
        >>= (\activeScreen ->
              screenBorders
                .   fromMaybe screenError
                .   lookup activeScreen
                <$> input @Screens
            )
  stateToInput :: Member (State a) r => Sem (Input a ': r) b -> Sem r b
  stateToInput = interpret $ \case
    Input -> get

data KeyStatus = New KeyStatus Mode KeyCode | Temp KeyStatus Mode KeyCode | Dead KeyStatus | Default
makeBaseFunctor ''KeyStatus

instance Show KeyStatus where
  show _ = "Key status"

