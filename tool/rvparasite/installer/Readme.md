Install Scripts for rvparasite
==============================

下記のスクリプトの*いずれか*を実行すると、rvpがインストールされます。

* `install_rvp.bat`
* `install_rvp_4ap.bat`

## アンインストールについて

アンインストーラーはありません。下記の説明を参考に、手作業で元に戻す必要があります。

## install_rvp.bat

一部のプロジェクトでのみ rvp を使用する場合は、`install_rvp.bat`を実行してください。

このスクリプトを実行すると、次の処理を行います。

1. 元の`SciLexer.dll`を`SciLexer\SciLexer.dll`に退避する。
2. `SciLexer.dll`を退避したフォルダにパスを通す。

補足:

* 2.のパスは、レジストリの`HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\RPGVxAce.exe`に設定されます。
* rvpを使用したいプロジェクトでは、rvpの`scilexer.dll`と`hooks\`フォルダを、対象のプロジェクトにコピーしてください。

## install\_rvp\_4ap.bat

全てのプロジェクトで rvp を使用する場合は、`install_rvp_4ap.bat`を実行してください。

1. 元の`SciLexer.dll`を`SciLexer\SciLexer.dll`に退避する。
2. rvpの`scilexer.dll`を元の`SciLexer.dll`の代わりにコピーする。

補足:

* プロジェクトのフォルダにrvpの`scilexer.dll`をコピーする必要は*ありません*。
* 全てのプロジェクトに`hooks\`フォルダをコピーする必要が*あります*。コピーしない場合、フックするアクションを実行した際にエラーが通知されます（フック対象の元の動作（保存など）は正しく行われます）。


