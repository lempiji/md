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

言語に `d` または `D` と指定されているコードブロックが実行されます。

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


### dub.sdlの直接設定

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

tempディレクトリに `.md` ディレクトリを作り、dubのシングルファイル形式のソースを生成、 `dub run --single md_xxx.md` といったコマンドで実行します。

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