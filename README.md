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


### 使い方

##### 0.機器のシリアルコンソールを握る

ここでは screen あるいは cu を想定しています

```
自分のPCで
% sudo screen /dev/tty.usbserialXXX 9600
または
% sudo cu -l /dev/tty.usbserialXXX -s 9600
```

##### 1.ターゲットのC3560を初期化する

パスワードがわかっている場合は以下の通り設定をすべて吹き飛ばしましょう。vlan.datの削除も忘れずに。

```
# erase startup-config
# delete flash:vlan.dat
# reload
```

あるいは最初からパスワードリカバリーによる初期化を行う場合は以下の手順を踏みます

```
電源接続時にMODEボタンを押し続けて30秒程度まち、"switch: "プロンプトが出てくるのをまつ

出てきたら以下の通りフラッシュの初期化、コンフィグの移動、起動を行う
switch: flash_init
switch: rename flash:config.text flash:config.text.old
switch: boot
```

##### 2.initial configuration ダイアログをすりぬける

初期化後の起動時になにかダイアログが出てきますが "no" を選択してすり抜けます

```
Would you like to enter the initial configuration dialog? [yes/no]: no
あるいは
Continue with configuration dialog? [yes/no]:no
```

##### 3.sreen/cuを落とす

以下のプロンプトが出ている状態でscreenあるいはcuを落とします
```
Switch>

screenなら"^a+k"
cuなら"~~"
```

##### 4.conbu-c3560-detchupを実行する

```
たとえばSW101をターゲットに実行する場合

% sudo ruby ./conbu-c3560-detchup.rb -c config.json -t c3560-template.txt -s SW101 -C /dev/tty.usbserialXXX
```

途中で設定されるコンフィグが表示されるので確認してENTER、やめる場合はctrl + c


##### 5.再度シリアルコンソールを握り、コンフィグ確認 & write memory

write memoryまでは行わないため、再度screenなどで入りコンフィグをチェックした上でwrite memoryないしcopy run startしてください。


### コンフィグのパラメータ

コンフィグ(config.json)は以下のような構造のJSONファイルです。

```
{
	"common": {        # 複数機器間で共通のパラメータを書く場所
		"user": "testuser",
		...
	},

	"SW101": {         # スイッチごとに固有のパラメータを書く場所
		"port":
	},
	...                # 各スイッチの設定が並ぶ
}
```

テンプレート内では共通パラメータを common 、個別パラメータを my として参照可能です。
コマンドのsオプションで指定したスイッチ名と上記"SW101"といった文字列が照合され、マッチする名前のコンフィグ内のエントリが my に格納されます。

基本的にはハッシュに書いた内容がそのまま渡されます。

特殊な利用をされるパラメータとして以下があります。

- port: スイッチのポート数(24 or 48)を指定
  - アップリンクポートの番号やダウンリンクポートの位置を自動生成(後述)
- use-gbe-uplink-port: 指定した番号のGEインタフェースをアップリンクポートに指定
  - GLC-Tを使う場合に利用
- use-gbe-downlink-port: ダウンリンクポートとして使うGEインタフェース番号の配列
  - ダウンリンク側にもGLC-Tを使う場合に利用
  - 配列でない場合無効

ただし、以下のパラメータがテンプレートエンジンにより自動的に生成されます。

- "acl-cloud-prefix"から生成
  - "acl-cloud-network": acl-cloud-prefixから生成されたネットワークアドレス
  - "acl-cloud-mask": acl-cloud-prefixのプレフィクスから生成されたaccess-list用ネットマスク
- sオプションから生成
  - "hostname": ターゲットの名前をそのまま利用
- "mgmt-addr"
  - "mgmt-addr-host": mgmt-addrからプレフィクスを除いた部分
  - "mgmt-addr-netmask": mgmt-addrのプレフィクスから生成されたネットマスク
- "port"から生成
  - "uplink-port": 最老番 (24か48)
  - "downlink-port-tail": 最追番-1
  - "downlink-port-tail": 最追番-3 (よって3ポートのみ)

