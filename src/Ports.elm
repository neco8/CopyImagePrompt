port module Ports exposing (Codec, Msg(..), MsgId, closeModal, copy, loadFromLocalStorage, onPaste, openModal, paste, receiveLoadResult, receiveModalStatus, receiveSaveResult, saveToLocalStorage, update)

import Json.Decode
import Json.Encode
import Util


type alias Codec a =
    { decoder : Json.Decode.Decoder a
    , encoder : a -> Json.Encode.Value
    , path : List String
    }


saveToLocalStorage : Codec a -> a -> Cmd msg
saveToLocalStorage codec value =
    saveToLocalStoragePort <|
        Json.Encode.object
            [ ( "path", Json.Encode.list Json.Encode.string codec.path )
            , ( "value", codec.encoder value )
            ]


receiveSaveResult : (Bool -> msg) -> Sub msg
receiveSaveResult =
    receiveSaveResultPort


loadFromLocalStorage : Codec a -> MsgId -> Cmd msg
loadFromLocalStorage codec msgId =
    loadFromLocalStoragePort <|
        Json.Encode.object
            [ ( "path", Json.Encode.list Json.Encode.string codec.path )
            , ( "msg", Json.Encode.string msgId )
            ]


type alias MsgId =
    String


type alias LoadResult =
    { msg : String
    , value : Json.Decode.Value
    }


type Msg msg
    = UserMsg msg
    | ReceiveLoadResult Json.Decode.Value


loadResultDecoder : Json.Decode.Decoder LoadResult
loadResultDecoder =
    Json.Decode.map2 LoadResult
        (Json.Decode.field "msg" Json.Decode.string)
        (Json.Decode.field "value" Json.Decode.value)


update : List ( MsgId, Json.Decode.Value -> msg ) -> (msg -> model -> ( model, Cmd msg )) -> Msg msg -> model -> ( model, Cmd (Msg msg) )
update receiveMsgSettings updateInner msg model =
    case msg of
        UserMsg m ->
            updateInner m model |> Tuple.mapSecond (Cmd.map UserMsg)

        ReceiveLoadResult value ->
            case Json.Decode.decodeValue loadResultDecoder value of
                Ok result ->
                    let
                        validMsgs =
                            List.filterMap
                                (\( msgId, tagger ) ->
                                    if msgId == result.msg then
                                        Just (tagger result.value)

                                    else
                                        Nothing
                                )
                                receiveMsgSettings
                    in
                    ( model, Cmd.none )
                        |> List.foldl
                            (\m prevFunc ->
                                prevFunc
                                    >> Util.andThen (update receiveMsgSettings updateInner (UserMsg m))
                            )
                            identity
                            validMsgs

                Err err ->
                    ( model, Cmd.none )


receiveLoadResult : Sub (Msg msg)
receiveLoadResult =
    receiveLoadResultPort ReceiveLoadResult


port copy : String -> Cmd msg


port paste : String -> Cmd msg


port onPaste : (String -> msg) -> Sub msg


port openModal : String -> Cmd msg


port closeModal : String -> Cmd msg


port receiveModalStatus : (Bool -> msg) -> Sub msg


port saveToLocalStoragePort : Json.Encode.Value -> Cmd msg


port receiveSaveResultPort : (Bool -> msg) -> Sub msg


port loadFromLocalStoragePort : Json.Encode.Value -> Cmd msg


port receiveLoadResultPort : (Json.Encode.Value -> msg) -> Sub msg
