module Util exposing (..)

andThen : (a -> ( b, Cmd msg )) -> ( a, Cmd msg ) -> ( b, Cmd msg )
andThen a ( model, cmd0 ) =
    let
        ( nextModel, cmd1 ) =
            a model
    in
    ( nextModel, Cmd.batch [ cmd0, cmd1 ] )
