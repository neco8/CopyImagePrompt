# Prompts to Commands: Midjourneyプロンプト生成の悩みを解決する

noteを定期的に書いていた時期に、noteのヘッダーをMidjourneyで生成しようと思ったことがあります。でも、プロンプトを考えるのが面倒で、ChatGPTに複数のプロンプトを考えてもらっていました。

結構めんどくさかった覚えがあります。当時、私はDALL･EよりもMidjourneyのほうが使いごこちが好きだったので、Midjourneyを使っていました。

でも、そのMidjourneyのプロンプトを貼り付けるのが、結構めんどくさかったのです。私は毎日ヘッダー画像を作りたかったのですが、MidjourneyはDiscord上でコマンドを打つ必要があります。それに加えて、Discord上の画像生成プロンプトのコマンドは、画像の大きさや解像度、ネガティブプロンプトなど、たくさんの指定できるオプションが存在していました。

そういうオプションをChatGPTに任せるには、精度が足りませんでした。だから、とりあえず画像のプロンプトだけChatGPTにたくさん生成してもらって、それらをJSONとして入力してもらい、Midjourneyのプロンプトをコピーできるボタンをたくさん作るようなツールを作りました。

そういう、困ったことがあったときに自分でツールを作ることの楽しさを、どうにかして伝えたいと思っています。とっても楽しいんです。ついでに、勉強にもなります。

ツールを作るときに重要だと思うことは、作り込みすぎないことと、難しくしないことです。適当にできるなら、適当にする。改善はあとからでもできます。

## 🌟 主な機能

- ChatGPTを使用したプロンプトの生成
- 貼り付けられたプロンプトの変換とコピー

## 🚀 インストール方法

このアプリは以下のURLで公開されています:
https://neco8.github.io/CopyImagePrompt/

## 📝 使用方法

1. 上記のURLにアクセスします。
2. ChatGPTでプロンプトを生成する場合:
  - アコーディオン部分を開きます。
  - themeを入力します。
  - generateボタンを押します。
3. 貼り付けられたプロンプトを変換する場合:
  - クリップボードからテキストエリアにプロンプトを貼り付けます。(ボタンクリックで貼り付け可能)
  - プロンプトは自動的に変換されます。
  - 必要に応じて、変換オプション(ReplacersとAffixers)を設定します。
    - Replacer: 文字列を置換する機能 (複数設定可能)
    - Affixer: プロンプトの前後に文字列を追加する機能 (複数設定可能)
4. 変換されたプロンプトをコピーします。
  - テキストエリアの内容に応じて生成されたコピーボタン群から、目的のボタンをクリックします。
5. コピーしたプロンプトをMidjourneyで使用します。

## 🔗 関連リンク

**Midjourney関連:**
- [Midjourney公式サイト](https://www.midjourney.com) - Midjourneyの公式サイト。最新のアップデート情報やよくある質問などが掲載されている。
- [Midjourney公式ドキュメント](https://docs.midjourney.com/) - Midjourneyの公式ドキュメント。プロンプトの書き方、パラメータの設定、アップスケール方法など、Midjourneyを使いこなすための詳細な説明が網羅されている。

**ChatGPT関連:**
- [OpenAI APIリファレンス](https://platform.openai.com/docs/api-reference) - OpenAI APIの各エンドポイントの仕様が説明されている。

**Elm関連:**
- [An Introduction to Elm（日本語訳）](https://guide.elm-lang.jp) - Elmの公式ガイドの日本語訳。Elmの基本的な文法やThe Elm Architectureによる開発手法などが解説されている。
- [An Introduction to Elm（原文）](https://guide.elm-lang.org) - 上記の原文。

**daisyUI関連:**
- [daisyUI公式サイト](https://daisyui.com) - daisyUIの公式サイト。Tailwind CSSベースのコンポーネントライブラリの概要、使い方、テーマのカスタマイズ方法などが説明されている。
- [daisyUIテーマのドキュメント](https://daisyui.com/docs/themes/) - daisyUIの提供するテーマの一覧と、テーマの適用方法、カスタムテーマの作成方法などが詳しく解説されている。

## 🔮 今後の展望

現在、「Prompts to Commands」はあくまでも個人的なツールであり、大規模なアップデートや定期的な更新は予定していません。
