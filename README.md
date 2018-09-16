### CONBU C3560 向けでっちあげスクリプト

CONBUで使っている C3560-48PS あるいは C3560-24PS をよしなな状態にセットアップしてくれる子。

```
書式
sudo ruby ./conbu-c3560-detchup.rb -c [コンフィグ] -t [テンプレート] -s [ターゲットの名前] -C [コンソールデバイス]

例
sudo ruby ./conbu-c3560-detchup.rb -c sample.config.json -t c3560-template.txt  -s SW001 -C /dev/tty.usbserialXXXX
```

- C3560 (FastEther版) のみ対応
- 実行にあたりcuが必要です
- C3560でerase startup-config と reload をした状態で実行してください
- 他のターミナルのscreen/cuは全部落とした状態で実行してください
- エラーチェック等はないので目でgrepしてください。
- 設定可能なパラメータは sample.config.json をご参照ください

