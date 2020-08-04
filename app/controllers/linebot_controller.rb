class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      return head :bad_request
    end

    events = client.parse_events_from(body)
    
    events.each { |event|
      case event
        # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']
          case input
            # 「マルバツ」or「まるばつ」というワードが含まれる場合
          when /.*(マルバツ|まるばつ).*/
            client.reply_message(event['replyToken'], template)
          when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
            push =
              "ありがとう！！！\n優しい言葉をかけてくれるあなたはとても素敵です(^^)"
          when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
            push =
              "こんにちは。\n声をかけてくれてありがとう\n今日があなたにとっていい日になりますように(^^)"
          end
          # テキスト以外（画像等）のメッセージが送られた場合
        else
          push = "テキスト以外はわからないよ〜(；；)"
        end
        message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)

        # ユーザーの回答に対しての正誤案内
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          answer = event.message['text']
          case answer
          # 「マルの場合」or「バツの場合」で返事を変える
          when /.*(マル).*/
            client.reply_message(event['replyToken'], answer_true)
          when /.*(バツ).*/
          client.reply_message(event['replyToken'], answer_false)
          
          end

        # LINEお友達追された場合（機能②）
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # LINEお友達解除された場合（機能③）
      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def template
    {
      "type": "template",
      "altText": "this is a confirm template",
      "template": {
          "type": "confirm",
          "text": "!aとはtrueの場合にfalse、falseの場合にtrueを返す論理演算子である",
          "actions": [
              {
                "type": "message",
                # Botから送られてきたメッセージに表示される文字列です。
                "label": "マル",
                # ボタンを押した時にBotに送られる文字列です。
                "text": "マル"
              },
              {
                "type": "message",
                "label": "バツ",
                "text": "バツ"
              }
          ]
      }
    }
  end

  def answer_true
    answer =
    {
      type: 'text',
      text: "正解です！お見事！！\n論理演算子には&&や||もあります。\n復習しておきましょう！"
    }
  end

  def answer_false
    answer = 
    {
      type: 'text',
      text: "残念！不正解！" 
    }
  end

end