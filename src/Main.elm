port module Main exposing (main)

import Browser exposing (Document)
import Html exposing (Attribute, Html, button, div, input, label, option, select, span, text, textarea, ul)
import Html.Attributes exposing (checked, class, disabled, id, placeholder, rows, selected, tabindex, type_, value)
import Html.Events exposing (on, onCheck, onClick, onInput, preventDefaultOn, targetValue)
import Json.Decode
import Json.Encode
import Process exposing (sleep)
import Task


type BeforeOrAfter
    = Before
    | After


type ImageType
    = NoteHeader
    | ApplicationMockup
    | ApplicationIcon


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
    | OnClickCopyButton Int String
    | OnClickCopyImagePromptButton ImageType
    | AddToast { milliseconds : Float, toastStr : String }
    | DeleteToast Int
    | OnPaste String
    | PasteToJsonInput
    | DeleteReplacer Int


noop : a -> ( a, Cmd msg )
noop model =
    ( model, Cmd.none )


andThen : (a -> ( b, Cmd msg )) -> ( a, Cmd msg ) -> ( b, Cmd msg )
andThen a ( model, cmd0 ) =
    let
        ( nextModel, cmd1 ) =
            a model
    in
    ( nextModel, Cmd.batch [ cmd0, cmd1 ] )


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

        OnClickCopyButton index str ->
            ( model, Cmd.none )
                |> andThen (\prev -> ( prev, copy str ))
                |> andThen (addToast 2000 ("Midjourney Prompt " ++ (String.fromInt <| index + 1) ++ " is copied!"))
                |> andThen (\prev -> ( { prev | copiedIndices = index :: prev.copiedIndices }, Cmd.none ))

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
            ( model, paste jsonInputId )

        OnPaste str ->
            ( { model | jsonInput = str }, Cmd.none )

        AddReplacer ->
            ( { model | replacers = model.replacers ++ [ { before = "", after = "" } ] }, Cmd.none )

        ToggleChatGPTPromptGenerater ->
            ( { model | chatGPTPromptGeneraterCollapsed = not model.chatGPTPromptGeneraterCollapsed }, Cmd.none )

        ToggleOptions ->
            ( { model | optionsCollapsed = not model.optionsCollapsed }, Cmd.none )

        OnClickCopyImagePromptButton imageType ->
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
            ( model, copy imagePrompt )
                |> andThen
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


init : () -> ( Model, Cmd Msg )
init () =
    ( { jsonInput = ""
      , themeInput = ""
      , chatGPTPromptGeneraterCollapsed = False
      , optionsCollapsed = True
      , toastModels = []
      , replacers =
            [ { before = "--v 5.2.", after = "--v 5.2" }
            , { before = "--v 5.1", after = "--v 5.2" }
            , { before = " --q 2", after = "" }
            , { before = "📷 ", after = "" }
            ]
      , affixers =
            [ { affix = Prefix, string = "/imagine prompt:", enabled = True }
            ]
      , copiedIndices = []
      }
    , Cmd.none
    )


copyButtonView : { a | copied : Bool, index : Int, str : String } -> Html Msg
copyButtonView props =
    button
        [ class "btn"
        , if props.copied then
            class "btn-secondary"

          else
            class "btn-primary"
        , onClick (OnClickCopyButton props.index props.str)
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
                Json.Decode.decodeString (Json.Decode.list Json.Decode.string) props.jsonInput
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
            [ text "Get started to paste JSON string!"
            ]


collapseView : { a | collapsed : Bool, onToggle : msg, collapseLabel : String } -> List (Html msg) -> Html msg
collapseView props content =
    div [ class "collapse collapse-arrow rounded-lg bg-slate-100 overflow-visible" ]
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


configCardView : { a | label : String, itemViews : List (Html msg), class : Attribute msg } -> Html msg
configCardView props =
    div [ class "grid grid-flow-row gap-4 p-6 rounded-lg border border-slate-200 shadow-sm bg-white", props.class ] <|
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
                    div [ class "grid grid-flow-col grid-cols-[1fr,auto] gap-4" ]
                        [ div [ class "grid grid-flow-col gap-4" ]
                            [ input
                                [ class "input input-bordered"
                                , value a.before
                                , onInput (InputReplacer index Before)
                                ]
                                []
                            , input
                                [ class "input input-bordered"
                                , value a.after
                                , onInput (InputReplacer index After)
                                ]
                                []
                            ]
                        , button [ class "btn btn-square btn-outline", onClick (DeleteReplacer index) ] [ text "x" ]
                        ]
                )
                props.replacers
                ++ [ button [ class "btn btn-outline", onClick AddReplacer ] [ text "add replacer" ]
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
                    div [ class "grid grid-flow-col grid-cols-[auto,1fr,auto,auto] gap-4 items-center" ]
                        [ select [ class "select select-bordered", onSelectAffix (ChangeAffixAffixer index) ] <|
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
                            [ class "input input-bordered"
                            , value a.string
                            , onInput (InputAffixer index)
                            ]
                            []
                        , input
                            [ type_ "checkbox"
                            , checked a.enabled
                            , onCheck (always (ToggleEnabledAffixer index))
                            , class "toggle"
                            ]
                            []
                        , button [ class "btn btn-square btn-outline", onClick (DeleteAffixer index) ] [ text "x" ]
                        ]
                )
                props.affixers
                ++ [ button [ class "btn btn-outline", onClick AddAffixer ] [ text "add affixer" ]
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


view : Model -> Document Msg
view model =
    let
        body =
            div [ class "grid gap-8 p-10" ]
                [ collapseView
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
                        , div [ class "dropdown dropdown-hover dropdown-bottom dropdown-end" ]
                            [ label [ tabindex 0, class "btn join-item btn-outline" ] [ text "generate" ]
                            , ul [ tabindex 0, class "dropdown-content z-[2] menu p-2 shadow bg-base-100 rounded-box" ]
                                [ button
                                    [ onClick (OnClickCopyImagePromptButton NoteHeader)
                                    , class "btn btn-ghost whitespace-nowrap justify-start"
                                    ]
                                    [ text "note header" ]
                                , button
                                    [ onClick (OnClickCopyImagePromptButton ApplicationMockup)
                                    , class "btn btn-ghost whitespace-nowrap justify-start"
                                    ]
                                    [ text "application mockup" ]
                                , button
                                    [ onClick (OnClickCopyImagePromptButton ApplicationIcon)
                                    , class "btn btn-ghost whitespace-nowrap justify-start"
                                    ]
                                    [ text "application icon" ]
                                ]
                            ]
                        ]
                    ]
                , optionsView model
                , button [ class "btn btn-outline", onClick PasteToJsonInput ] [ text "paste image prompts as json" ]
                , textareaView
                    { placeholder = "Image Prompts as JSON format. ✍"
                    , value = model.jsonInput
                    , onInput = InputJSON
                    , id = jsonInputId
                    , rows = 10
                    , class = "p-6"
                    }
                , buttonsView model
                , toastsView model.toastModels
                ]
    in
    { title = "Image prompter"
    , body = [ body ]
    }


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ onPaste OnPaste
        ]


main : Program () Model Msg
main =
    Browser.application
        { init = \f url key -> init f
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = \url -> NoOp
        , onUrlRequest = \urlRequest -> NoOp
        }



-----


getNoteHeaderImagePrompt : String -> String
getNoteHeaderImagePrompt theme =
    """ChatGPT, here's a detailed task I need you to execute based on the theme "<Theme>":

Understanding <Theme>: First, grasp the essence of "<Theme>".
It's crucial that you understand this correctly, as it's the foundation for the following tasks.

Sketch Ideas: Next, using <Theme> as a basis, I'd like you to conceptualize 10 abstract symbols or designs that can express or represent it.
I'm looking for just brief textual descriptions of these symbols or ideas, not actual sketches.

Random Selection: Once you have those 10 ideas, randomly choose 3 out of them.
It's essential that this selection is random, so do not prioritize any particular concept.

Photorealistic Plugin Integration: For these 3 selected ideas, use the photorealistic plugin to generate prompts for midjourney. Here's a VERY important note for the plugin: Set the parameters to '--ar 1920:1006' NOT '--ar 16:9'.
Please, I can't stress this enough.
Make sure the plugin gets this right, even if you need to emphasize it multiple times.
Misinterpretation of these parameters can lead to undesirable results.

Output in JSON: Finally, the generated prompts from the plugin should be presented as an array of strings in JSON format.
This means, your output should look something like: ["...", "...", "...", ...].

Please, execute the above steps with utmost precision. Any deviation or misunderstanding can impact the final output.
---
<Theme>
""" ++ theme


getApplicationIconImagePrompt : String -> String
getApplicationIconImagePrompt theme =
    """Hello ChatGPT, based on the theme '<Theme>', please follow these instructions with precision:

[INSTRUCTIONS]
1. Propose 10 textual descriptions for application icons that reflect the essence of '<Theme>'.
2. Randomly select 3 out of those 10 descriptions.
3. Detail the process to create modern and simple application icons. Highlight the essential features for crafting these icons into a midjourney prompt.
4. For each of the 3 selected descriptions, generate midjourney prompts for WHITE BACKGROUND APPLICATION ICONS. Ensure that the prompts lead to modern and simple application icons. Replace <Theme> with the actual theme.

[RESTRICTIONS]
- Parameters: Use '--v 5.2' and '--ar 1:1'. It's crucial to set these correctly.
- Format: Provide the prompts in JSON format as an array of strings, not objects.
- Description: Focus on describing the image itself in detail. The goal is to achieve a unique, modern, and simple application icon look.

# Note: Emphasizing the importance of creating modern and simple application icons.
# Ensure the parameters '--v 5.2' and '--ar 1:1' are at the end of each prompt.
# Use the photorealistic plugin for generating the midjourney prompts.

---
<Theme>: """ ++ theme ++ """
<Instruction>: Generate the prompt of `""" ++ theme ++ """`.
"""


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



-----


port copy : String -> Cmd msg


port paste : String -> Cmd msg


port onPaste : (String -> msg) -> Sub msg
