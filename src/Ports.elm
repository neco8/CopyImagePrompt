port module Ports exposing (..)


port copy : String -> Cmd msg


port paste : String -> Cmd msg


port onPaste : (String -> msg) -> Sub msg


port openModal : String -> Cmd msg


port closeModal : String -> Cmd msg


port receiveModalStatus : (Bool -> msg) -> Sub msg
