// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library linter.src.rules.directives_ordering;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:linter/src/analyzer.dart';

const _dartImportGoFirst = r"Place 'dart:' imports before other imports.";
const _desc = r'Adhere to Effective Dart Guide directives sorting conventions.';
const _details =
    r'''**DO** follow the conventions in the [Effective Dart Guide](https://www.dartlang.org/guides/language/effective-dart/style#ordering)

**DO** place “dart:” imports before other imports.

**BAD:**
```
import 'package:bar/bar.dart';
import 'package:foo/foo.dart';

import 'dart:async';  // LINT
import 'dart:html';  // LINT
```

**BAD:**
```
import 'dart:html';  // OK
import 'package:bar/bar.dart';

import 'dart:async';  // LINT
import 'package:foo/foo.dart';
```

**GOOD:**
```
import 'dart:async';  // OK
import 'dart:html';  // OK

import 'package:bar/bar.dart';
import 'package:foo/foo.dart';
```

**DO** place “package:” imports before relative imports.

**BAD:**
```
import 'a.dart';
import 'b.dart';

import 'package:bar/bar.dart';  // LINT
import 'package:foo/foo.dart';  // LINT
```
**BAD:**
```
import 'package:bar/bar.dart';  // OK
import 'a.dart';

import 'package:foo/foo.dart';  // LINT
import 'b.dart';
```

**GOOD:**
```
import 'package:bar/bar.dart';  // OK
import 'package:foo/foo.dart';  // OK

import 'a.dart';
import 'b.dart';
```

**PREFER** placing “third-party” “package:” imports before other imports.

**BAD:**
```
import 'package:myapp/io.dart';
import 'package:myapp/util.dart';

import 'package:bar/bar.dart';  // LINT
import 'package:foo/foo.dart';  // LINT
```

**GOOD:**
```
import 'package:bar/bar.dart';  // OK
import 'package:foo/foo.dart';  // OK

import 'package:myapp/io.dart';
import 'package:myapp/util.dart';
```

**DO** specify exports in a separate section after all imports.

**BAD:**
```
import 'src/error.dart';
export 'src/error.dart'; // LINT
import 'src/string_source.dart';
```

**GOOD:**
```
import 'src/error.dart';
import 'src/string_source.dart';

export 'src/error.dart'; // OK
```

**DO** sort sections alphabetically.

**BAD:**
```
import 'package:foo/bar.dart'; // OK
import 'package:bar/bar.dart'; // LINT

import 'a/b.dart'; // OK
import 'a.dart'; // LINT
```

**GOOD:**
```
import 'package:bar/bar.dart'; // OK
import 'package:foo/bar.dart'; // OK

import 'a.dart'; // OK
import 'a/b.dart'; // OK

''';

const _directiveSectionOrderedAlphabetically =
    r"Sort directive sections alphabetically.";

const _exportDirectiveAfterImportDirectives =
    r"Specify exports in a separate section after all imports.";

const _packageImportBeforeRelative =
    r"Place 'package:' imports before relative imports.";

const _thirdPartyPackageImportBeforeOwn =
    r"Place 'third-party' 'package:' imports before other imports.";

bool _isAbsoluteImport(ImportDirective node) => node.uriContent.contains(":");

bool _isDartImport(ImportDirective node) => node.uriContent.startsWith("dart:");

bool _isExportDirective(Directive node) => node is ExportDirective;

bool _isImportDirective(Directive node) => node is ImportDirective;

bool _isNotDartImport(ImportDirective node) => !_isDartImport(node);

bool _isPackageImport(ImportDirective node) =>
    node.uriContent.startsWith("package:");

bool _isRelativeImport(ImportDirective node) => !_isAbsoluteImport(node);

class DirectivesOrdering extends LintRule implements ProjectVisitor {
  _Visitor _visitor;
  DartProject project;

  DirectivesOrdering()
      : super(
            name: 'directives_ordering',
            description: _desc,
            details: _details,
            group: Group.style) {
    _visitor = new _Visitor(this);
  }

  @override
  ProjectVisitor getProjectVisitor() => this;

  @override
  AstVisitor getVisitor() => _visitor;

  @override
  visit(DartProject project) {
    this.project = project;
  }

  void _reportLintWithDartImportGoFirstMessage(AstNode node) {
    _reportLintWithDescription(node, _dartImportGoFirst);
  }

  void _reportLintWithDescription(AstNode node, String description) {
    reporter.reportErrorForNode(new LintCode(name, description), node, []);
  }

  void _reportLintWithDirectiveSectionOrderedAlphabeticallyMessage(
      AstNode node) {
    _reportLintWithDescription(node, _directiveSectionOrderedAlphabetically);
  }

  void _reportLintWithExportDirectiveAfterImportDirectiveMessage(AstNode node) {
    _reportLintWithDescription(node, _exportDirectiveAfterImportDirectives);
  }

  void _reportLintWithPackageImportBeforeRelativeMessage(AstNode node) {
    _reportLintWithDescription(node, _packageImportBeforeRelative);
  }

  void _reportLintWithThirdPartyPackageImportBeforeOwnMessage(AstNode node) {
    _reportLintWithDescription(node, _thirdPartyPackageImportBeforeOwn);
  }
}

class _PackageBox {
  final String _packageName;
  _PackageBox(this._packageName);

  bool _isNotOwnPackageImport(ImportDirective node) =>
      _isPackageImport(node) && !_isOwnPackageImport(node);

  bool _isOwnPackageImport(ImportDirective node) =>
      node.uriContent.startsWith('package:$_packageName/');
}

class _Visitor extends SimpleAstVisitor {
  final DirectivesOrdering rule;

  _Visitor(this.rule);

  DartProject get project => rule.project;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    Set<AstNode> lintedNodes = new Set<AstNode>();
    _checkDartImportGoFirst(lintedNodes, node);
    _checkPackageImportBeforeRelative(lintedNodes, node);
    _checkThirdPartyImportBeforeOwn(lintedNodes, node);
    _checkExportDirectiveAfterImportDirective(lintedNodes, node);
    _checkDirectiveSectionOrderedAlphabetically(lintedNodes, node);
  }

  void _checkDartImportGoFirst(Set<AstNode> lintedNodes, CompilationUnit node) {
    void reportDirective(ImportDirective directive) {
      if (lintedNodes.add(directive)) {
        rule._reportLintWithDartImportGoFirstMessage(directive);
      }
    }

    _getImportDirectives(node)
        .skipWhile(_isDartImport)
        .where(_isDartImport)
        .forEach(reportDirective);
  }

  void _checkDirectiveSectionOrderedAlphabetically(
      Set<AstNode> lintedNodes, CompilationUnit node) {
    final importDirectives = _getImportDirectives(node);
    final exportDirectives = _getExportDirectives(node);

    final dartImports = importDirectives.where(_isDartImport);
    final relativeImports = importDirectives.where(_isRelativeImport);

    _checkSectionInOrder(lintedNodes, dartImports);
    _checkSectionInOrder(lintedNodes, relativeImports);
    _checkSectionInOrder(lintedNodes, exportDirectives);

    if (project != null) {
      _PackageBox packageBox = new _PackageBox(project.name);

      final thirdPartyPackageImports =
          importDirectives.where(packageBox._isNotOwnPackageImport);
      final ownPackageImports =
          importDirectives.where(packageBox._isOwnPackageImport);

      _checkSectionInOrder(lintedNodes, thirdPartyPackageImports);
      _checkSectionInOrder(lintedNodes, ownPackageImports);
    }
  }

  void _checkExportDirectiveAfterImportDirective(
      Set<AstNode> lintedNodes, CompilationUnit node) {
    void reportDirective(Directive directive) {
      if (lintedNodes.add(directive)) {
        rule._reportLintWithExportDirectiveAfterImportDirectiveMessage(
            directive);
      }
    }

    node.directives.reversed
        .skipWhile(_isExportDirective)
        .where(_isExportDirective)
        .forEach(reportDirective);
  }

  void _checkPackageImportBeforeRelative(
      Set<AstNode> lintedNodes, CompilationUnit node) {
    void reportDirective(ImportDirective directive) {
      if (lintedNodes.add(directive)) {
        rule._reportLintWithPackageImportBeforeRelativeMessage(directive);
      }
    }

    _getImportDirectives(node)
        .where(_isNotDartImport)
        .skipWhile(_isAbsoluteImport)
        .where(_isPackageImport)
        .forEach(reportDirective);
  }

  void _checkSectionInOrder(
      Set<AstNode> lintedNodes, Iterable<NamespaceDirective> nodes) {
    void reportDirective(NamespaceDirective directive) {
      if (lintedNodes.add(directive)) {
        rule._reportLintWithDirectiveSectionOrderedAlphabeticallyMessage(
            directive);
      }
    }

    NamespaceDirective previousDirective;
    for (NamespaceDirective directive in nodes) {
      if (previousDirective != null && previousDirective.uriContent.compareTo(directive.uriContent) > 0) {
        reportDirective(directive);
      }
      previousDirective = directive;
    }
  }

  void _checkThirdPartyImportBeforeOwn(
      Set<AstNode> lintedNodes, CompilationUnit node) {
    if (project == null) {
      return;
    }

    void reportDirective(ImportDirective directive) {
      if (lintedNodes.add(directive)) {
        rule._reportLintWithThirdPartyPackageImportBeforeOwnMessage(directive);
      }
    }

    _PackageBox box = new _PackageBox(project.name);
    _getImportDirectives(node)
        .where(_isPackageImport)
        .skipWhile(box._isNotOwnPackageImport)
        .where(box._isNotOwnPackageImport)
        .forEach(reportDirective);
  }

  Iterable<ExportDirective> _getExportDirectives(CompilationUnit node) =>
      node.directives
          .where(_isExportDirective)
          .map((e) => e as ExportDirective);

  Iterable<ImportDirective> _getImportDirectives(CompilationUnit node) =>
      node.directives
          .where(_isImportDirective)
          .map((e) => e as ImportDirective);
}