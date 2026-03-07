# md

[English](README.md)

Markdownのコードブロックを実行するツールです。

これを使うことで、READMEに書かれたサンプルが動作することをCIで保証することなどができます。

サンプルリポジトリ: https://github.com/lempiji/sandbox-vuepress

## 実行方法

`dub fetch md` および `dub run md -- README.md` といったコマンドで実行できます。

この `README.md` も実行可能となっています。

なお、 `md` にコマンドライン引数を渡すことで、生成した D ソースファイルをどのように実行するか設定することもできます。

__ヘルプの参照方法__

```
dub run md -- --help
```


## 機能概要

言語に `d`, `D`, `sh`, `bash` と指定されているコードブロックが実行されます。

### ブロックの結合

以下のように複数のブロックがある場合、それらが結合されて実行されます。

__1ブロック目__

```d
import std;

auto message = "Hello, " ~ "Markdown!";
```

__2ブロック目__

```d
writeln(message); // Hello, Markdown!
```

### 除外設定

以下のように `disabled` と指定したコードブロックは実行されません。

~~~
```d disabled
```
~~~

__実行されないブロック__

```d disabled
throw new Exception("disabled");
```

### 名前指定

コードブロックに対して、以下のような名前を指定することで独立したスコープを与えることができます。
離れた位置に書かれていても、同じ名前を与えると1つのブロックとして結合されます。

~~~
```d name=test
```
~~~

```d name=test
import std;

auto buf = iota(10).array();
writeln(buf);
```

`name` 指定がない場合は `main` という名前として扱われます。

#### 名前フィルター

`--filter` オプションを指定することで、特定の名前を持つコードブロックのみを実行することができます。

__例__

~~~
```d name=filter_test
```
~~~

```
dub run md -- README.md --filter=filter_test --filter=filter_test2
```

```d name=filter_test
import std;

auto message = "filter test";
writeln(message);
```

```d name=filter_test2
import std;

auto message2 = "another filter test";
writeln(message2);
```

#### 複数の名前指定

1つのコードブロックに対して、複数の `name` 属性を指定できます。
このブロックは、指定したすべての名前のブロックに取り込まれます。

~~~
```d name=multi_name_test1 name=multi_name_test2
```
~~~

```
dub run md -- README.md --filter=multi_name_test1
dub run md -- README.md --filter=multi_name_test2
```

```d name=multi_name_test1 name=multi_name_test2
import std.stdio;
```

```d name=multi_name_test1
writeln("multi-name test1");
```

```d name=multi_name_test2
writeln("multi-name test2");
```

### シェルブロック

`sh` と `bash` のブロックも、Dと同じ `name` と `--filter` のルールで実行されます。
`name` 省略時は `main` 扱いで、1つのブロックに複数の `name` も指定できます。

~~~
```sh name=shell_sample
```
~~~

```
dub run md -- README.md --filter=shell_sample
dub run md -- README.md --filter=bash_sample
```

```sh name=shell_sample
shared_shell="from-sh"
echo "sh:${shared_shell}"
```

```bash name=shell_sample name=bash_sample
shared_bash="from-bash"
```

```bash name=bash_sample
parts=("A" "B")
echo "bash:${shared_bash}:${parts[1]}"
```

実行方式:
1. `sh` ブロックは `sh -eu <temp_script_path>` で実行
2. `bash` ブロックは `bash -eu -o pipefail <temp_script_path>` で実行
3. OS に関わらず、対応するインタプリタが `PATH` 上にある環境で実行
4. `bash` ブロックには `bash`、`sh` ブロックには `sh` が必要
5. 実行時のカレントディレクトリは `md` コマンドを起動したディレクトリ
6. 終了コードが0以外なら失敗扱い
7. インタプリタを起動できない場合も、そのブロックは失敗扱い
8. `--build`, `--compiler`, `--arch`, `--dependency`, `--dubsdl` はD実行にのみ適用
9. `--buildOnly` 指定時はシェルスクリプトを生成するが実行はスキップ
10. `--show-lang` を指定すると begin/end ラベルを `<language>:<block-name>` 形式で表示（既定は従来形式）

### 独立実行

1つのコードブロックを他のブロックと結合せず、独立して実行させるためには `single` という属性を付与します。

~~~
```d single
```
~~~

__他のブロックと結合しない例__

```d single
import std;

auto message = "single code block";
writeln(message);
```

### dubのビルドオプションサポート

ツールによる実行(`dub run`)に渡すことができるいくつかのオプションをサポートしています。
これらのオプションは、指定された値をそのまま `dub run` の引数として渡します。

1. `--build`
2. `--compiler`
3. `--arch`

__例__

```
dub run md -- README.md --build=release --compiler=ldc2 --arch=x86_64
```

### 既定のパッケージ参照

ライブラリのREADMEなどをサポートするため、実行時のカレントディレクトリがdubパッケージであった場合、自動的に `dub` プロジェクトとしての依存関係が追加されます。（これは `dub.sdl` に `path` ベースの `dependency` が追加されます）

たとえば、 `dub.sdl` と同じディレクトリにある本READMEの場合、内部で使っている `commands.main` を `import` することができます。

```d name=package_ref
import commands.main;
import std.stdio;

writeln("current package: ", loadCurrentProjectName());
```

### 追加のパッケージ参照

`-d <pakageName>` や `-d <pakageName>@<versionString>` （`-d mir-ion@~>2.0.16` など）の指定によって追加の依存関係を設定することもできます。（`-d` の正式名は `--dependency` です）


### dub.sdlの直接設定（テストされていません）

`--dubsdl <instruction>` を指定すると、生成されるファイルに dub.sdl の行を直接追加することができます。このオプションは複数回指定することで複数の行を追加することもできます。
このオプションを指定した場合、上記の「既定のパッケージ参照機能」が無効化され、参照が追加されなくなります。


### グローバル宣言

通常のコードブロックはサンプル用の記述を想定し、 `void main() {}` の中に書かれたものとして実行されます。（前後に `void main() {` と `}` が補われたソースが生成されます）

コードブロックを1つのソースファイルとして解釈させる場合、コードブロックに `global` という設定を追加します。これは `single` を指定した場合と同様、他のコードブロックとは結合されません。

~~~
```d global
```
~~~

__1つのソースとして実行される例__

```d global
import std;

void main()
{
    writeln("Hello, Markdown!");
}
```


## その他

### 実行時の仕組み

tempディレクトリに `.md` ディレクトリを作り、実行単位ごとの一時ファイルを生成して実行します。

言語ごとの実行方式:
1. D: dubのシングルファイル形式ソースを生成し、 `dub run --single md_xxx.d` で実行（`--buildOnly` 時は `dub build --single ...`）
2. sh: スクリプトを生成し、 `sh -eu md_xxx.sh` で実行
3. bash: スクリプトを生成し、 `bash -eu -o pipefail md_xxx.sh` で実行

名前付きブロックは `language + name` 単位で結合され、 `--filter` 指定時は対象nameのみ実行されます。

また、既定のパッケージ参照を実現するため、ソースの先頭に以下のようなコメントを自動的に付与します。

```d disabled
/+ dub.sdl:
    dependency "md" path="C:\\work\md"
 +/
```

### 制限

#### UFCS

通常のコードブロックでは、 `void main() {}` で囲んだソースを生成します。
関数定義がグローバル関数ではないため、UFCSは動作しません

__UFCSが解決されず動かない例__

```d disabled
auto sum(R)(R range)
{
    import std.range : ElementType;

    alias E = ElementType!R;
    auto result = E(0);
    foreach (x; range)
    {
        result += x;
    }
    return result;
}

auto arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
auto result = arr.sum();
```

global設定を行い、main関数を適切に書くことで動作します。

__UFCSのためglobal指定を追加した例__

```d global
auto sum(R)(R range)
{
    import std.range : ElementType;

    alias E = ElementType!R;
    auto result = E(0);
    foreach (x; range)
    {
        result += x;
    }
    return result;
}

void main()
{
    auto arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    auto result = arr.sum();
}
```
