# Fujitsu FM-11用 NitrOS-9

[English version](README.md.en)

このリポジトリは、[NitrOS-9](https://github.com/nitros9project/nitros9) を Fujitsu FM-11 向けに移植したものです。

上流の NitrOS-9 ソースツリーをベースにした fork として管理しており、可能な限り FM-11 固有の実装を分離しながら、上流の変更を取り込める構成を維持しています。

## 現在の状況

FM-11 向け **NitrOS-9 Level 1 / Level 2** の移植は、いずれも基本実装を完了しています。

6809版とHD63C09版の双方について、2D / 2HDフロッピーおよびHDDからの起動と通常操作を確認しています。

### 共通ハードウェア／デバイス対応

Level 1 / Level 2 のデバイス対応状況は次の通りです。

- Motorola 6809 / Hitachi HD63C09
- FM-11ローカルコンソール
- USART0シリアル端末
- 5.25インチ 2D FDD
- 5.25インチ 2HD FDD
- 富士通製FM-11用HDD


### Level 1

Level 1では、次の機能を実装しています。

- RBF / RBSuper
- Pipe
- ANSI / VT100端末制御
- `format`
- `cobbler`
- `os9gen`
- `more`
- MinTED / dEd
- 各種標準コマンド、ディスクユーティリティ

FM-11固有のLevel 1ソースは主に次にあります。

```text
level1/fm11/
```

### Level 2

Level 2では、FM-11の4 KiB MMRページを2枚ずつ組み合わせ、NitrOS-9 Level 2からは通常の8 KiB DATブロックとして扱う方式を採用しています。

現在の実装には次が含まれます。

- 4 KiB MMRページを用いた8 KiBペアMMU実装
- FM-11用kernel trampoline
- RBF / RBSuper
- Pipe / Shell pipeline
- ANSI / VT100端末制御
- `format`
- `cobbler`
- `os9gen`
- Level 2用メモリ／プロセス診断コマンド

FM-11固有のLevel 2ソースは主に次にあります。

```text
level2/fm11/
```

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

### ブランクHDDイメージ

HDDイメージはLevelやCPUに依存しません。指定したHDD機種と同じgeometryのブランクイメージを生成します。

```sh
scripts/fm11/make-hdd-image.sh m2233b
```

生成例:

```text
fm11-m2233b.img
```

この段階ではIPL、boot track、RBF filesystem、OSファイルは入っていません。FM-11エミュレータでHDD機種を設定してから接続し、NitrOS-9上で初期化します。


## FDD構成

物理デバイス名はLevel 1 / Level 2で共通です。

```text
/MD0, /MD1 = 5.25インチ 2D
/ND0, /ND1 = 5.25インチ 2HD
```

Level 1 / Level 2とも、システムプロファイルに応じて論理名 `/D0`～`/D3` も使用します。

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

## HDD構成と利用方法

HDDのデバイス名はLevel 1 / Level 2とも `/H0` です。FM-11エミュレータで現在サポートしているHDD機種に合わせてdescriptorとbootlistを用意しています。

対応機種:

```text
M2230B  315 cylinders x  2 heads
M2231B  157 cylinders x  4 heads
M2232B  157 cylinders x  6 heads
M2233B  315 cylinders x  4 heads
M2234B  315 cylinders x  6 heads
M2235B  315 cylinders x  8 heads
M2241B  747 cylinders x  4 heads
M2242B  747 cylinders x  7 heads
M2243B  747 cylinders x 11 heads
```

すべて32 sectors/track、256 bytes/sectorです。既定のHDD profileはM2233Bです。

例えばM2233Bを利用する場合、ホスト側でブランクイメージを生成します。

```sh
scripts/fm11/make-hdd-image.sh m2233b
```

エミュレータでこのイメージをM2233Bとして接続し、Level 1またはLevel 2のシステムFDDから起動します。NitrOS-9上では、まずHDDを初期化します。

```text
format /h0
```

現在起動中のシステム構成を基にbootable HDDを作る場合は `cobbler` を利用できます。

```text
cobbler /h0
```

bootlistを明示してOS9Bootを生成する場合は `os9gen` を利用します。M2233Bの例:

```text
os9gen /h0 < /DD/SYS/BOOTLISTS/bootlist.hd.m2233b
```

ほかのHDD機種では末尾の機種名を変更します。`bootlist.hd` は既定のM2233B profileです。

HDDを通常のシステムディスクとして利用する場合は、必要に応じてシステムFDDの `/DD/CMDS` や `/DD/SYS` の内容をHDD側にコピーしてください。IPLとBootp1は `cobbler` / `os9gen` が `/DD/SYS/IPL` と `/DD/SYS/BOOT` から読み込みます。


## `/DD/SYS` の構成

FM-11版では、Level 1 / Level 2で `/DD/SYS` 配下の配置規約を共通化しています。

代表的な構成:

```text
/DD/SYS/IPL/
    IPL.2D
    IPL.2HD
    IPL.HD

/DD/SYS/BOOT/
    Bootp1.2D
    Bootp1.2HD
    Bootp1.HD

/DD/SYS/MODULES/
    ... bootfile生成用モジュール ...

/DD/SYS/BOOTLISTS/
    bootlist.2d
    bootlist.2hd
    bootlist.hd
    bootlist.hd.m2230b
    ...
    bootlist.hd.m2243b
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

これにより、NitrOS-9 Level 2本来の8 KiBメモリ管理をできるだけ維持しつつ、FM-11のMMRに対応しています。

## 既知の注意点

- FM-11エミュレータによっては、HD63C09命令実装に差があります。6309版の動作検証には対応済みのエミュレータを使用してください。

## Upstream

本リポジトリはNitrOS-9 projectをベースにしています。

[NitrOS-9 Project](https://github.com/nitros9project/nitros9)

上流の変更を取り込みながら、FM-11固有実装を本リポジトリで維持します。

## License

本リポジトリは、上流NitrOS-9ソースのライセンス条件を継承します。

個々のファイルに追加のcopyright／license記述がある場合は、それぞれのソースファイルおよび上流projectの記述を参照してください。
