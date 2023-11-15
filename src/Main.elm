module Main exposing (main)

import Browser exposing (Document)
import Html exposing (Attribute, Html, a, button, div, form, h2, img, input, label, li, node, option, select, span, text, textarea, ul)
import Html.Attributes exposing (attribute, checked, class, id, method, placeholder, rows, src, tabindex, type_, value)
import Html.Events exposing (on, onCheck, onClick, onInput, onSubmit, preventDefaultOn, targetValue)
import Icon
import Json.Decode
import Json.Encode
import Ports
import Process exposing (sleep)
import Task
import Util
import VitePluginHelper as V


type BeforeOrAfter
    = Before
    | After


type ImageType
    = NoteHeader
    | ApplicationMockup
    | ApplicationIcon


type OverlayModel
    = OverlayNone
    | DrawerOpened
    | ModalOpened


type Msg
    = NoOp
    | InputJSON String
    | InputTheme String
    | ToggleChatGPTPromptGenerater
    | ToggleOptions
    | InputReplacer Int BeforeOrAfter String
    | AddReplacer
    | InputAffixer Int String
    | ToggleEnabledAffixer Int
    | ChangeAffixAffixer Int Affix
    | DeleteAffixer Int
    | AddAffixer
    | ClickCopyButton Int String
    | ClickCopyImagePromptButton ImageType
    | AddToast { milliseconds : Float, toastStr : String }
    | DeleteToast Int
    | Paste String
    | PasteToJsonInput
    | DeleteReplacer Int
    | OpenModal
    | CloseModal
    | OpenDrawer
    | CloseDrawer
    | ReceiveModalStatus Bool
    | ReceiveSettings Json.Decode.Value


noop : a -> ( a, Cmd msg )
noop model =
    ( model, Cmd.none )


addToast : Float -> String -> { a | toastModels : List ToastModel } -> ( { a | toastModels : List ToastModel }, Cmd Msg )
addToast milliseconds toastStr model =
    let
        newToastId =
            getNewToastId model.toastModels
    in
    ( { model
        | toastModels =
            { id = newToastId
            , toastStr = toastStr
            }
                :: model.toastModels
      }
    , sleep milliseconds
        |> Task.andThen (always (Task.succeed (DeleteToast newToastId)))
        |> Task.perform identity
    )


updateReplacers : Int -> BeforeOrAfter -> String -> List { a | before : String, after : String } -> List { a | before : String, after : String }
updateReplacers index beforeOrAfter str replacers =
    let
        updateReplacer replacer s =
            case beforeOrAfter of
                Before ->
                    { replacer | before = s }

                After ->
                    { replacer | after = s }
    in
    List.indexedMap
        (\i a ->
            if i == index then
                updateReplacer a str

            else
                a
        )
        replacers


updateAffixers :
    Int
    -> ({ affixer | affix : Affix, string : String, enabled : Bool } -> { affixer | affix : Affix, string : String, enabled : Bool })
    -> List { affixer | affix : Affix, string : String, enabled : Bool }
    -> List { affixer | affix : Affix, string : String, enabled : Bool }
updateAffixers index updater affixers =
    List.indexedMap
        (\i a ->
            if i == index then
                updater a

            else
                a
        )
        affixers


updateRaw : Msg -> Model -> ( Model, Cmd Msg )
updateRaw msg model =
    case msg of
        NoOp ->
            noop model

        ClickCopyButton index str ->
            ( model, Cmd.none )
                |> Util.andThen (\prev -> ( prev, Ports.copy str ))
                |> Util.andThen (addToast 2000 ("Midjourney Prompt " ++ (String.fromInt <| index + 1) ++ " is copied!"))
                |> Util.andThen (\prev -> ( { prev | copiedIndices = index :: prev.copiedIndices }, Cmd.none ))

        InputJSON str ->
            ( { model | jsonInput = str }, Cmd.none )

        InputTheme str ->
            ( { model
                | themeInput = str
              }
            , Cmd.none
            )

        InputReplacer index beforeOrAfter str ->
            ( { model | replacers = updateReplacers index beforeOrAfter str model.replacers }, Cmd.none )

        DeleteReplacer index ->
            ( { model
                | replacers =
                    model.replacers
                        |> List.indexedMap
                            (\i a ->
                                if i == index then
                                    Nothing

                                else
                                    Just a
                            )
                        |> List.filterMap identity
              }
            , Cmd.none
            )

        InputAffixer index str ->
            ( { model
                | affixers =
                    updateAffixers index
                        (\affixer -> { affixer | string = str })
                        model.affixers
              }
            , Cmd.none
            )

        ToggleEnabledAffixer index ->
            ( { model
                | affixers =
                    updateAffixers index
                        (\affixer -> { affixer | enabled = not affixer.enabled })
                        model.affixers
              }
            , Cmd.none
            )

        ChangeAffixAffixer index affix ->
            ( { model
                | affixers =
                    updateAffixers index
                        (\affixer -> { affixer | affix = affix })
                        model.affixers
              }
            , Cmd.none
            )

        DeleteAffixer index ->
            ( { model
                | affixers =
                    model.affixers
                        |> List.indexedMap
                            (\i a ->
                                if i == index then
                                    Nothing

                                else
                                    Just a
                            )
                        |> List.filterMap identity
              }
            , Cmd.none
            )

        AddAffixer ->
            ( { model
                | affixers =
                    model.affixers ++ [ { affix = Prefix, string = "", enabled = True } ]
              }
            , Cmd.none
            )

        AddToast { milliseconds, toastStr } ->
            addToast milliseconds toastStr model

        DeleteToast id ->
            ( { model
                | toastModels =
                    model.toastModels
                        |> List.filter
                            (\toast ->
                                toast.id /= id
                            )
              }
            , Cmd.none
            )

        PasteToJsonInput ->
            ( model, Ports.paste jsonInputId )

        Paste str ->
            ( { model | jsonInput = str }, Cmd.none )

        AddReplacer ->
            ( { model | replacers = model.replacers ++ [ { before = "", after = "" } ] }, Cmd.none )

        ToggleChatGPTPromptGenerater ->
            ( { model | chatGPTPromptGeneraterCollapsed = not model.chatGPTPromptGeneraterCollapsed }, Cmd.none )

        ToggleOptions ->
            ( { model | optionsCollapsed = not model.optionsCollapsed }, Cmd.none )

        ClickCopyImagePromptButton imageType ->
            let
                imagePrompt =
                    (case imageType of
                        NoteHeader ->
                            getNoteHeaderImagePrompt

                        ApplicationMockup ->
                            getApplicationMockupImagePrompt

                        ApplicationIcon ->
                            getApplicationIconImagePrompt
                    )
                        model.themeInput
            in
            ( model, Ports.copy imagePrompt )
                |> Util.andThen
                    (addToast 2000
                        ((case imageType of
                            NoteHeader ->
                                "Note Header"

                            ApplicationMockup ->
                                "Application Mockup"

                            ApplicationIcon ->
                                "Application Icon"
                         )
                            ++ " prompt copied!"
                        )
                    )

        OpenModal ->
            ( model, Ports.openModal settingsModalId )

        CloseModal ->
            ( model, Ports.closeModal settingsModalId )

        OpenDrawer ->
            ( { model | overlayModel = DrawerOpened }, Cmd.none )

        CloseDrawer ->
            ( { model | overlayModel = OverlayNone }, Cmd.none )

        ReceiveModalStatus modalOpened ->
            ( { model
                | overlayModel =
                    if modalOpened then
                        ModalOpened

                    else
                        OverlayNone
              }
            , Cmd.none
            )

        ReceiveSettings value ->
            case Json.Decode.decodeValue settingsCodec.decoder value of
                Ok settings ->
                    noop model

                Err err ->
                    noop model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        ( updatedModel, updatedCmd ) =
            updateRaw msg model
    in
    ( updatedModel
        |> resetCopiedIndices model
    , updatedCmd
    )


type alias ToastModel =
    { id : Int
    , toastStr : String
    }


getNewToastId : List { a | id : number } -> number
getNewToastId =
    List.map .id
        >> List.maximum
        >> Maybe.map (\x -> x + 1)
        >> Maybe.withDefault 0


type Affix
    = Prefix
    | Suffix


affixAll : List Affix
affixAll =
    let
        next list =
            case List.head list of
                Nothing ->
                    Prefix :: list |> next

                Just Prefix ->
                    Suffix :: list |> next

                Just Suffix ->
                    list
    in
    next [] |> List.reverse


type alias Model =
    { jsonInput : String
    , themeInput : String
    , chatGPTPromptGeneraterCollapsed : Bool
    , optionsCollapsed : Bool
    , toastModels : List ToastModel
    , replacers : List { before : String, after : String }
    , affixers : List { affix : Affix, string : String, enabled : Bool }
    , copiedIndices : List Int
    , overlayModel : OverlayModel
    }


resetCopiedIndices :
    { model | jsonInput : String, copiedIndices : List Int, replacers : c }
    -> { model | jsonInput : String, copiedIndices : List Int, replacers : c }
    -> { model | jsonInput : String, copiedIndices : List Int, replacers : c }
resetCopiedIndices before after =
    if before.jsonInput /= after.jsonInput then
        { after | copiedIndices = [] }

    else if before.replacers /= after.replacers then
        { after | copiedIndices = [] }

    else
        after


init : () -> ( Model, Cmd (Ports.Msg Msg) )
init () =
    ( { jsonInput = ""
      , themeInput = ""
      , chatGPTPromptGeneraterCollapsed = False
      , optionsCollapsed = True
      , toastModels = []
      , replacers =
            [ { before = "--v 5.1", after = "--v 5.2" }
            , { before = "--v 5.2.", after = "--v 5.2" }
            , { before = " --q 2", after = "" }
            , { before = "📷 ", after = "" }
            ]
      , affixers =
            [ { affix = Prefix, string = "/imagine prompt:", enabled = True }
            , { affix = Suffix, string = " --style raw", enabled = False }
            ]
      , copiedIndices = []
      , overlayModel = OverlayNone
      }
    , Cmd.none
    )


navbarView : { a | hamburgerClass : Attribute msg, checkedHamburger : Bool, onCheckHamburger : Bool -> msg } -> Html msg
navbarView props =
    div [ class "navbar bg-base-100 shadow-md rounded-lg p-3" ]
        [ div [ class "navbar-start" ]
            [ label [ class "btn swap swap-rotate bg-transparent border-transparent hover:bg-transparent hover:border-transparent text-slate-400 hover:text-slate-800", props.hamburgerClass ]
                [ input [ type_ "checkbox", checked props.checkedHamburger, onCheck props.onCheckHamburger ] []
                , Icon.iconView { iconType = Icon.Menu, class = class "swap-off text-sm" }
                , Icon.iconView { iconType = Icon.Close, class = class "swap-on text-sm" }
                ]
            ]
        , div [ class "navbar-center" ]
            [ button [ class "btn normal-case btn-ghost text-sm md:text-xl transition-all duration-200" ]
                [ img [ src <| V.asset "/assets/favicon.ico/apple-touch-icon.png?inline", class "mask mask-squircle h-6" ] []
                , text "Prompts to Commands"
                ]
            ]
        , div [ class "navbar-end" ] []
        ]


drawerView : { a | drawerOpened : Bool, class : Attribute Msg } -> List (Html Msg) -> Html Msg
drawerView props children =
    div [ class "drawer lg:drawer-open", props.class ]
        [ input [ type_ "checkbox", checked props.drawerOpened, class "drawer-toggle" ] []
        , div [ class "drawer-content" ] children
        , div [ class "drawer-side z-10" ]
            [ label [ attribute "aria-label" "close sidebar", class "drawer-overlay", onClick CloseDrawer ] []
            , ul [ class "menu p-4 w-80 min-h-full bg-base-200 text-base-content" ]
                [ li [ class "text-lg text-slate-600", onClick OpenModal ]
                    [ a []
                        [ Icon.iconView { iconType = Icon.Settings, class = class "text-lg" }
                        , text "Settings"
                        ]
                    ]
                ]
            ]
        ]


settingsModalId : String
settingsModalId =
    "settings"


settingsModalView : {} -> Html Msg
settingsModalView props =
    node "dialog"
        [ class "modal", id settingsModalId ]
        [ div [ class "modal-box grid" ]
            [ h2 [ class "text-lg font-bold text-slate-800" ] [ text "Settings" ]
            , span [ class "mt-2 text-slate-500" ] [ text "Coming soon..." ]
            ]
        , form [ method "dialog", class "modal-backdrop", onSubmit CloseModal ] [ button [] [ text "Close" ] ]
        ]


copyButtonView : { a | copied : Bool, index : Int, str : String } -> Html Msg
copyButtonView props =
    button
        [ class "btn"
        , if props.copied then
            class "btn-secondary"

          else
            class "btn-primary"
        , onClick (ClickCopyButton props.index props.str)
        ]
        [ text ("Copy Image Prompt " ++ String.fromInt (props.index + 1)) ]


buttonsView :
    { a
        | replacers : List { b | before : String, after : String }
        , jsonInput : String
        , copiedIndices : List Int
        , affixers : List { c | affix : Affix, string : String, enabled : Bool }
    }
    -> Html Msg
buttonsView props =
    let
        replacer start =
            -- もしかしたらenabledを追加するかも
            List.foldl (\a -> String.replace a.before a.after) start props.replacers

        affixer start =
            List.foldl
                (\a ->
                    if a.enabled then
                        \str ->
                            case a.affix of
                                Prefix ->
                                    a.string ++ str

                                Suffix ->
                                    str ++ a.string

                    else
                        identity
                )
                start
                props.affixers

        isPromptGeneratingStarted =
            (not <|
                List.isEmpty
                    props.copiedIndices
            )
                || (not <|
                        String.isEmpty props.jsonInput
                   )

        result =
            Result.map
                (List.map
                    (replacer
                        >> affixer
                    )
                )
            <|
                Json.Decode.decodeString
                    (Json.Decode.oneOf
                        [ Json.Decode.list Json.Decode.string
                        , Json.Decode.string |> Json.Decode.map List.singleton
                        ]
                    )
                    props.jsonInput
    in
    if isPromptGeneratingStarted then
        case result of
            Ok as_ ->
                div
                    [ class "grid grid-flow-row gap-2"
                    ]
                <|
                    List.indexedMap
                        (\i a -> copyButtonView { str = a, index = i, copied = List.member i props.copiedIndices })
                        as_

            Err e ->
                div [ class "rounded-lg p-6 border-collapse bg-red-100 text-red-700" ]
                    [ text <| Json.Decode.errorToString e
                    ]

    else
        div [ class "rounded-lg p-6 border-collapse bg-teal-50 text-teal-800" ]
            [ text "Get started by pasting an array of strings in JSON format!"
            ]


collapseView : { a | collapsed : Bool, onToggle : msg, collapseLabel : String } -> List (Html msg) -> Html msg
collapseView props content =
    div [ class "w-full" ]
        [ div [ class "collapse collapse-arrow rounded-lg bg-slate-100 overflow-visible" ]
            [ input
                [ class "hover:cursor-pointer"
                , type_ "radio"
                , checked <| not props.collapsed
                , preventDefaultOn "click" (Json.Decode.succeed ( props.onToggle, False ))
                ]
                []
            , div
                [ class "collapse-title px-6 py-4 text-slate-600 rounded-lg"
                , if props.collapsed then
                    class "bg-slate-200"

                  else
                    class "bg-transparent"
                ]
                [ text props.collapseLabel ]
            , div [ class "form-control collapse-content px-6" ]
                content
            ]
        ]


configCardView : { a | label : String, itemViews : List (Html msg), class : Attribute msg } -> Html msg
configCardView props =
    div [ class "grid grid-flow-row gap-3 p-4 rounded-lg border border-slate-200 shadow-sm bg-white", props.class ] <|
        label [ class "text-sm text-slate-600" ] [ text props.label ]
            :: props.itemViews


replacersView : { a | replacers : List { b | before : String, after : String }, class : Attribute Msg } -> Html Msg
replacersView props =
    configCardView
        { label = "Replacers"
        , class = props.class
        , itemViews =
            List.indexedMap
                (\index a ->
                    div [ class "grid grid-flow-col grid-cols-[1fr,min-content] gap-3" ]
                        [ div [ class "grid grid-cols-2 gap-3" ]
                            [ input
                                [ class "input input-bordered p-2"
                                , value a.before
                                , onInput (InputReplacer index Before)
                                , placeholder "before"
                                ]
                                []
                            , input
                                [ class "input input-bordered p-2"
                                , value a.after
                                , onInput (InputReplacer index After)
                                , placeholder "after"
                                ]
                                []
                            ]
                        , button [ class "btn btn-ghost", onClick (DeleteReplacer index) ]
                            [ Icon.iconView { class = class "text-sm", iconType = Icon.Close }
                            ]
                        ]
                )
                props.replacers
                ++ [ button [ class "btn btn-outline w-full", onClick AddReplacer ] [ text "add replacer" ]
                   ]
        }


affixToValue : Affix -> String
affixToValue a =
    case a of
        Prefix ->
            "prefix"

        Suffix ->
            "suffix"


affixDecoder : Json.Decode.Decoder Affix
affixDecoder =
    targetValue
        |> Json.Decode.andThen
            (\s ->
                case s of
                    "prefix" ->
                        Json.Decode.succeed Prefix

                    "suffix" ->
                        Json.Decode.succeed Suffix

                    _ ->
                        Json.Decode.fail <| "This is invalid value." ++ s
            )


onSelectAffix : (Affix -> msg) -> Attribute msg
onSelectAffix tagger =
    on "input" (Json.Decode.map tagger affixDecoder)


affixersView : { a | affixers : List { b | string : String, enabled : Bool, affix : Affix }, class : Attribute Msg } -> Html Msg
affixersView props =
    configCardView
        { label = "Affixer"
        , itemViews =
            List.indexedMap
                (\index a ->
                    div [ class "grid grid-flow-col grid-cols-[min-content,1fr,min-content,min-content] gap-3 items-center" ]
                        [ select [ class "select select-bordered p-2", onSelectAffix (ChangeAffixAffixer index) ] <|
                            List.map
                                (\affix ->
                                    option
                                        [ value <| affixToValue affix ]
                                        [ text <|
                                            case affix of
                                                Prefix ->
                                                    "← Prefix"

                                                Suffix ->
                                                    "→ Suffix"
                                        ]
                                )
                                affixAll
                        , input
                            [ class "input input-bordered w-full"
                            , value a.string
                            , onInput (InputAffixer index)
                            , placeholder "add..."
                            ]
                            []
                        , input
                            [ type_ "checkbox"
                            , checked a.enabled
                            , onCheck (always (ToggleEnabledAffixer index))
                            , class "toggle toggle-xs toggle-primary sm:toggle-sm md:toggle-md"
                            ]
                            []
                        , button [ class "btn btn-ghost", onClick (DeleteAffixer index) ] [ text "x" ]
                        ]
                )
                props.affixers
                ++ [ button [ class "btn btn-outline max-w-full", onClick AddAffixer ] [ text "add affixer" ]
                   ]
        , class = props.class
        }


optionsView :
    { a
        | optionsCollapsed : Bool
        , replacers : List { b | before : String, after : String }
        , affixers : List { c | affix : Affix, string : String, enabled : Bool }
    }
    -> Html Msg
optionsView model =
    collapseView
        { collapsed = model.optionsCollapsed
        , onToggle = ToggleOptions
        , collapseLabel = "Options"
        }
        [ replacersView
            { replacers = model.replacers
            , class = class ""
            }
        , affixersView
            { affixers = model.affixers
            , class = class "mt-4"
            }
        ]


textareaView : { a | class : String, placeholder : String, value : String, onInput : String -> msg, id : String, rows : Int } -> Html msg
textareaView props =
    textarea
        [ class "textarea textarea-bordered"
        , if String.isEmpty props.class then
            class ""

          else
            class props.class
        , placeholder props.placeholder
        , value props.value
        , onInput props.onInput
        , id props.id
        , rows props.rows
        ]
        []


toastsView : List ToastModel -> Html Msg
toastsView toastModels =
    div
        [ class "toast toast-top toast-end z-[2]"
        ]
    <|
        List.map
            (\toast ->
                div
                    [ class "alert alert-info"
                    , onClick (DeleteToast toast.id)
                    ]
                    [ text toast.toastStr ]
            )
        <|
            toastModels


jsonInputId : String
jsonInputId =
    "jsonInput"


view : Model -> Document (Ports.Msg Msg)
view model =
    let
        body =
            drawerView { drawerOpened = model.overlayModel == DrawerOpened, class = class "font-poppins" } <|
                [ div [ class "grid gap-8 p-6 sm:p-10 w-full" ]
                    [ navbarView
                        { checkedHamburger = model.overlayModel == DrawerOpened
                        , onCheckHamburger =
                            \hamburgerChecked ->
                                if hamburgerChecked then
                                    OpenDrawer

                                else
                                    CloseDrawer
                        , hamburgerClass = class "lg:hidden"
                        }
                    , collapseView
                        { onToggle = ToggleChatGPTPromptGenerater
                        , collapseLabel = "Generate ChatGPT Prompt"
                        , collapsed = model.chatGPTPromptGeneraterCollapsed
                        }
                        [ div [ class "join" ]
                            [ input
                                [ class "input input-bordered w-full join-item"
                                , value model.themeInput
                                , onInput InputTheme
                                , placeholder "theme:"
                                , preventDefaultOn "click" (Json.Decode.succeed ( NoOp, False ))
                                ]
                                []
                            , let
                                canGenerate =
                                    String.isEmpty model.themeInput
                                        |> not
                              in
                              div
                                [ class "dropdown dropdown-hover dropdown-bottom dropdown-end" ]
                                [ label
                                    [ tabindex <|
                                        if canGenerate then
                                            0

                                        else
                                            -1
                                    , class "btn join-item btn-outline"
                                    , if canGenerate then
                                        class ""

                                      else
                                        class "btn-disabled"
                                    ]
                                    [ text "generate" ]
                                , if canGenerate then
                                    ul [ tabindex 0, class "dropdown-content z-[2] menu p-2 shadow bg-base-100 rounded-box" ]
                                        [ button
                                            [ onClick (ClickCopyImagePromptButton NoteHeader)
                                            , class "btn btn-ghost whitespace-nowrap justify-start"
                                            ]
                                            [ text "note header" ]
                                        , button
                                            [ onClick (ClickCopyImagePromptButton ApplicationMockup)
                                            , class "btn btn-ghost whitespace-nowrap justify-start"
                                            ]
                                            [ text "application mockup" ]
                                        , button
                                            [ onClick (ClickCopyImagePromptButton ApplicationIcon)
                                            , class "btn btn-ghost whitespace-nowrap justify-start"
                                            ]
                                            [ text "application icon" ]
                                        ]

                                  else
                                    text ""
                                ]
                            ]
                        ]
                    , div [ class "grid grid-flow-row gap-4" ]
                        [ button [ class "btn btn-outline", onClick PasteToJsonInput ] [ text "paste image prompts as json array" ]
                        , optionsView model
                        , textareaView
                            { placeholder = "Image Prompts as JSON format. ✍"
                            , value = model.jsonInput
                            , onInput = InputJSON
                            , id = jsonInputId
                            , rows = 10
                            , class = "p-6"
                            }
                        ]
                    , buttonsView model
                    , toastsView model.toastModels
                    , settingsModalView {}
                    ]
                ]
    in
    { title = "Image prompter"
    , body =
        [ body |> Html.map Ports.UserMsg
        ]
    }


subscriptions : Model -> Sub (Ports.Msg Msg)
subscriptions _ =
    Sub.batch
        [ Ports.onPaste (Paste >> Ports.UserMsg)
        , Ports.receiveModalStatus
            (ReceiveModalStatus >> Ports.UserMsg)
        , Ports.receiveLoadResult
        ]


main : Program () Model (Ports.Msg Msg)
main =
    Browser.application
        { init = \f url key -> init f
        , update = Ports.update receiveMsgSettings update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = \url -> Ports.UserMsg NoOp
        , onUrlRequest = \urlRequest -> Ports.UserMsg NoOp
        }



-----
-- database


settingsIdMsg : ( Ports.MsgId, Json.Decode.Value -> Msg )
settingsIdMsg =
    ( "receiveSettings", ReceiveSettings )


receiveMsgSettings : List ( Ports.MsgId, Json.Decode.Value -> Msg )
receiveMsgSettings =
    [ settingsIdMsg ]


type alias Settings =
    {}


settingsCodec : Ports.Codec Settings
settingsCodec =
    { path = [ "settings" ]
    , decoder = Json.Decode.succeed {}
    , encoder = always Json.Encode.null
    }



-----


getNoteHeaderImagePrompt : String -> String
getNoteHeaderImagePrompt theme =
    """ChatGPT, I need your assistance with a creative task involving the theme "<Theme>":

1. Insight on <Theme>: Begin by discussing the concept of "<Theme>". Provide a brief overview to ensure that you have a proper understanding of it, as it will be the basis for the subsequent ideas.

2. Conceptualize Ideas: Based on <Theme>, please come up with 10 original concepts or symbols that could represent or be associated with the theme. I would like a short textual description for each concept or symbol.

3. Suggestion for Random Selection: If you had to suggest 3 concepts or symbols out of the 10 you create, which would you choose? While you cannot perform a random selection, please try to diversify the selections to cover different aspects of the theme.

4. Descriptions for Visualization: For the 3 suggested concepts or symbols, I would like you to elaborate and provide detailed descriptions suitable for an artist to use as a brief. The details should be vivid enough.
NOTE: Add suffix ` --ar 1920:1006 --style raw --v 5.2`

5. JSON Format Presentation: Finally, present the detailed descriptions as an array of strings in JSON format. Your output should resemble: `["Description of concept 1", "Description of concept 2", "Description of concept 3"]`.

I trust your creative input on this task. Your thoroughness and creativity are key for the final outcome.
---
<Theme>
""" ++ theme


getApplicationIconImagePrompt : String -> String
getApplicationIconImagePrompt theme =
    """Hello ChatGPT,

I need to develop a series of application icons that embody a theme to be specified later. These icons should reflect a modern design ethos with minimalist features. The icons must have a stark white background to reinforce their sleek and contemporary nature, with clean-cut lines implicitly conveying the theme.

Instructions:
1. Outline the key attributes of a modern and minimalist icon design.
2. List 10 creative descriptions that could encapsulate the core of the specified theme.
3. Select 3 descriptions at random from your list.
4. For each of the selected descriptions, provide a conceptual design for an application icon. These should maintain a minimalistic style with sharply defined lines against a white backdrop, ensuring they align with the theme.
5. Submit JSON String-array like `["...", "...", "..."]`

Important considerations:
- The icons should appear simple yet sophisticated, avoiding unnecessary details to maintain a clean and modern look.
- Add suffix '--v 5.2 --ar 1:1 --style raw --no realistic camera detail'.
- Maintain focus on the elements of modern iconography, such as distinct shapes, solid colors, and streamlined visuals.

I look forward to your structured and imaginative response.

---
<Theme>
""" ++ theme


getApplicationMockupImagePrompt : String -> String
getApplicationMockupImagePrompt theme =
    """Dear ChatGPT, I would like you to assist me in creating some text descriptions for a mockup mobile application page based on the <Theme>. Please follow these steps:

1. Propose 10 text suggestions that describe a mobile mockup page representing the <Theme>. These descriptions should be influenced by:
- A bright color palette with contrasting dark colors and a specific highlight color.
- A modern sans-serif font style with readable font size.
- Buttons and icons with a soft rounded shape.
- Strategically placed images or illustrations, either full-screen or sectioned.
- A clean mobile layout.

2. From the 10 suggestions, randomly select 3.

3. With these 3 selected descriptions, use the photorealistic plugin to generate prompts for midjourney. Remember, and I emphasize for clarity: 
- For midjourney use the parameter '--v 5.2' NOT '--v 5.1'. 
- For midjourney use the parameter '--ar 2:3' NOT '--ar 16:9'. 
- Prompt must be super simple and clean in English, not complecated.
- Medium must be super simple.
This is very crucial as the photorealistic plugin tends to get confused.

4. Convert the generated results into a JSON format as a string array, like so: ["...", "...", "...", ...]. Avoid creating an array of objects.
---
<Theme>
""" ++ theme
