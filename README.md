# Fujitsu FM-11用 NitrOS-9

[English version](README.md.en)

このリポジトリは、[NitrOS-9](https://github.com/nitros9project/nitros9) を Fujitsu FM-11 向けに移植したものです。

上流の NitrOS-9 ソースツリーをベースにした fork として管理しており、可能な限り FM-11 固有の実装を分離しながら、上流の変更を取り込める構成を維持しています。

## 現在の状況

FM-11 向け **NitrOS-9 Level 1 / Level 2** の移植は、いずれも基本実装を完了しています。

6809版とHD63C09版の双方について、2D / 2HDフロッピーからの起動と通常操作を確認しています。

### Level 1

Level 1では、次の機能を実装しています。

- Motorola 6809対応
- Hitachi HD63C09対応（native modeを含む）
- FM-11ローカルコンソール
- USART0シリアル端末 `/T1`
- 5.25インチ 2D FDD
- 5.25インチ 2HD FDD
- FM-11 HDDインターフェース
- RBF / RBSuper
- Pipe
- ANSI / VT100端末制御
- `format`
- `cobbler`
- `os9gen`
- `more`
- MinTED / dEd
- 各種標準コマンド、ディスクユーティリティ、診断コマンド

FM-11固有のLevel 1ソースは主に次にあります。

```text
level1/fm11/
```

### Level 2

Level 2では、FM-11の4 KiB MMRページを2枚ずつ組み合わせ、NitrOS-9 Level 2からは通常の8 KiB DATブロックとして扱う方式を採用しています。

現在の実装には次が含まれます。

- Motorola 6809対応
- Hitachi HD63C09対応
- 4 KiB MMRページを用いた8 KiBペアMMU実装
- FM-11用kernel trampoline
- FM-11ローカルコンソール
- USART0シリアル端末 `/T1`
- 5.25インチ 2D FDD
- 5.25インチ 2HD FDD
- RBF / RBSuper
- Pipe / Shell pipeline
- ANSI / VT100端末制御
- `format`
- `cobbler`
- `os9gen`
- Level 2用メモリ／プロセス診断コマンド
- 6809 / 6309双方のシステムイメージ生成

FM-11固有のLevel 2ソースは主に次にあります。

```text
level2/fm11/
```

現行のLevel 2標準bootlistではHDDモジュールを組み込んでいません。そのため、現在配布対象としているLevel 2システムはFDD起動を前提としています。HDD関連の低レベルコードやdescriptorはソースツリー内に残されています。

## ビルド環境

FM-11版のビルドには、主に次が必要です。

- [LWTOOLS](http://lwtools.projects.l-w.ca/) (`lwasm`)
- [ToolShed](https://github.com/n6il/toolshed) (`os9`)
- Python 3
- 標準的なUnixコマンドラインツール

Linux環境でのビルドを想定しています。

## ビルド方法

リポジトリをcloneします。

```sh
git clone https://github.com/sueyasu/fm11-nitros9.git
cd fm11-nitros9
```

FM-11用イメージ生成の共通入口は次です。

```sh
scripts/fm11/build-images.sh LEVEL CPU [MEDIA]
```

指定値は次の通りです。

```text
LEVEL : 1 | 2
CPU   : 6809 | 6309
MEDIA : 2d | 2hd | all
```

`MEDIA`を省略した場合は`all`です。

### Level 1

6809版の2D / 2HDイメージを作成する例:

```sh
scripts/fm11/build-images.sh 1 6809
```

6309版:

```sh
scripts/fm11/build-images.sh 1 6309
```

生成物:

```text
fm11-l1-6809-2d.rbf
fm11-l1-6809-2d.d88
fm11-l1-6809-2hd.rbf
fm11-l1-6809-2hd.d88

fm11-l1-6309-2d.rbf
fm11-l1-6309-2d.d88
fm11-l1-6309-2hd.rbf
fm11-l1-6309-2hd.d88
```

### Level 2

6809版:

```sh
scripts/fm11/build-images.sh 2 6809
```

6309版:

```sh
scripts/fm11/build-images.sh 2 6309
```

生成物:

```text
fm11-l2-6809-2d.rbf
fm11-l2-6809-2d.d88
fm11-l2-6809-2hd.rbf
fm11-l2-6809-2hd.d88

fm11-l2-6309-2d.rbf
fm11-l2-6309-2d.d88
fm11-l2-6309-2hd.rbf
fm11-l2-6309-2hd.d88
```

特定メディアだけを作成する場合は、例えば次のようにします。

```sh
scripts/fm11/build-images.sh 2 6809 2d
```

## FDD構成

物理デバイス名はLevel 1 / Level 2で共通です。

```text
/MD0, /MD1 = 5.25インチ 2D
/ND0, /ND1 = 5.25インチ 2HD
```

Level 1では、システムプロファイルに応じて論理名 `/D0`～`/D3` も使用します。

2Dシステム:

```text
/D0, /D1 = 2D
/D2, /D3 = 2HD
```

2HDシステム:

```text
/D0, /D1 = 2HD
/D2, /D3 = 2D
```

Level 2の現行bootlistでは、OS9Bootサイズを抑えるため `/D0`～`/D3` のalias descriptorを常駐させておらず、`/MD0`、`/MD1`、`/ND0`、`/ND1` を直接使用します。

## `/SYS` の構成

FM-11版では、Level 1 / Level 2で `/SYS` 配下の配置規約を共通化しています。

代表的な構成:

```text
/SYS/IPL/
    IPL.2D
    IPL.2HD
    IPL.HD

/SYS/BOOT/
    Bootp1.2D
    Bootp1.2HD
    Bootp1.HD

/SYS/MODULES/
    ... bootfile生成用モジュール ...

/SYS/bootlist.2d
/SYS/bootlist.2hd
```

`cobbler` と `os9gen` は、これらのファイルを `/DD/SYS` から読み込みます。

配置規約は共通ですが、Level 1とLevel 2ではIPL、Bootp1、各モジュールの内容が異なる場合があります。特にLevel 2のBootp1はREL / Boot / Krnを含むLevel 2専用kernel trackです。

## FM-11用ブート構成

FM-11では通常のRBF領域とは別に、FDDのcylinder 0をブート用に使用します。

Level 2では、IPLからREL / Boot / Krnを含むkernel trackをロードし、その後OS9Bootを読み込んでシステムを起動します。

`format`、`cobbler`、`os9gen` はFM-11固有のIPL / boot track配置に対応しています。

## ソースツリー

主なFM-11固有ファイル:

```text
defs/fm11.d
level1/fm11/
level2/fm11/
scripts/fm11/
```

### Level 1

```text
level1/fm11/
    bootlists/   boot module list
    cmds/        FM-11固有コマンド、移植コマンド、診断ツール
    ipl/         FM-11 IPL
    modules/     driver、descriptor、boot、console等
    sys/         FM-11固有システムファイル
```

### Level 2

```text
level2/fm11/
    bootlists/   Level 2 boot module list
    ipl/         Level 2用FM-11 IPL
    kernel/      FM-11固有kernel関連コード
    modules/     MMU、boot、driver、descriptor等
```

共通化が適切な上流ソースは直接利用し、大幅なFM-11固有変更はできるだけ `level1/fm11/` または `level2/fm11/` に分離しています。

## Level 2 MMUモデル

NitrOS-9 Level 2は8 KiB単位のDATを前提としていますが、FM-11のMMRは4 KiB単位です。

FM-11版では、連続する2つの4 KiB物理ページを1つの8 KiB論理ブロックとして扱います。

```text
OS-9 block 0 -> FM-11 MMR slot 0,1
OS-9 block 1 -> FM-11 MMR slot 2,3
OS-9 block 2 -> FM-11 MMR slot 4,5
...
OS-9 block 7 -> FM-11 MMR slot E,F
```

これにより、NitrOS-9 Level 2本来の8 KiBメモリ管理をできるだけ維持しつつ、FM-11のMMRへ対応しています。

## 既知の注意点

- Level 2の標準構成は現在FDD起動を対象としています。
- Level 2ではOS9Bootの初期ロードサイズに依存する問題が確認されており、bootlistは必要なモジュールに絞っています。
- そのため、Level 2のbootlistへモジュールを追加する場合はOS9Bootサイズにも注意してください。
- FM-11エミュレータによってはHD63C09命令実装に差があるため、6309版の検証には対応済みのエミュレータを使用してください。

## バージョン管理

このFM-11 portのGitHub上のバージョン管理は、次のtagから開始しています。

```text
fm11-v0.1
```

初期移植時に使用した内部的な版番号やtest番号は開発履歴であり、Git tagのバージョン体系には含めません。

## Upstream

本リポジトリはNitrOS-9 projectをベースにしています。

[NitrOS-9 Project](https://github.com/nitros9project/nitros9)

上流の変更を取り込みながら、FM-11固有実装を本リポジトリで維持します。

## License

本リポジトリは、上流NitrOS-9ソースのライセンス条件を継承します。

個々のファイルに追加のcopyright／license記述がある場合は、それぞれのソースファイルおよび上流projectの記述を参照してください。
