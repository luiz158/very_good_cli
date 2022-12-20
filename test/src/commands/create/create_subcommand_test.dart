import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:mason_logger/src/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:usage/usage.dart';
import 'package:very_good_cli/src/commands/create/create_subcommand.dart';
import 'package:very_good_cli/src/commands/create/templates/template.dart';
import 'package:path/path.dart' as p;

class MockTemplate extends Mock implements Template {}

class MockAnalytics extends Mock implements Analytics {}

class MockLogger extends Mock implements Logger {}

class MockProgress extends Mock implements Progress {}

class MockMasonGenerator extends Mock implements MasonGenerator {}

class MockBundle extends Mock implements MasonBundle {}

class MockGeneratorHooks extends Mock implements GeneratorHooks {}

class FakeLogger extends Fake implements Logger {}

class FakeDirectoryGeneratorTarget extends Fake
    implements DirectoryGeneratorTarget {}

class _TestCreateSubCommand extends CreateSubCommand {
  _TestCreateSubCommand({
    required this.template,
    required Analytics analytics,
    required Logger logger,
    required MasonGeneratorFromBundle? generatorFromBundle,
    required MasonGeneratorFromBrick? generatorFromBrick,
  }) : super(
          analytics: analytics,
          logger: logger,
          generatorFromBundle: generatorFromBundle,
          generatorFromBrick: generatorFromBrick,
        );

  @override
  final String name = 'test';

  @override
  final String description = 'Test command';

  @override
  final Template template;
}

class _TestCreateSubCommandWithOrgName extends _TestCreateSubCommand
    with OrgName {
  _TestCreateSubCommandWithOrgName({
    required Template template,
    required Analytics analytics,
    required Logger logger,
    required MasonGeneratorFromBundle? generatorFromBundle,
    required MasonGeneratorFromBrick? generatorFromBrick,
  }) : super(
          template: template,
          analytics: analytics,
          logger: logger,
          generatorFromBundle: generatorFromBundle,
          generatorFromBrick: generatorFromBrick,
        );
}

class _TestCreateSubCommandMultiTemplate extends CreateSubCommand
    with MultiTemplates {
  _TestCreateSubCommandMultiTemplate({
    required this.defaultTemplateName,
    required this.templates,
    required Analytics analytics,
    required Logger logger,
    required MasonGeneratorFromBundle? generatorFromBundle,
    required MasonGeneratorFromBrick? generatorFromBrick,
  }) : super(
          analytics: analytics,
          logger: logger,
          generatorFromBundle: generatorFromBundle,
          generatorFromBrick: generatorFromBrick,
        );

  @override
  final String name = 'test';

  @override
  final String description = 'Test command';

  @override
  final String defaultTemplateName;

  @override
  final List<Template> templates;
}

class _TestCommandRunner extends CommandRunner<int> {
  _TestCommandRunner({
    required this.command,
  }) : super('test', 'Test command runner') {
    addCommand(command);
  }

  final Command<int> command;
}

void main() {
  final generatedFiles = List.filled(10, const GeneratedFile.created(path: ''));

  late List<String> progressLogs;
  late Analytics analytics;
  late Logger logger;
  late Progress progress;

  setUpAll(() {
    registerFallbackValue(FakeDirectoryGeneratorTarget());
    registerFallbackValue(FakeLogger());
  });

  setUp(() {
    progressLogs = <String>[];

    analytics = MockAnalytics();
    when(
      () => analytics.sendEvent(any(), any(), label: any(named: 'label')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.waitForLastPing(timeout: any(named: 'timeout')),
    ).thenAnswer((_) async {});

    logger = MockLogger();

    progress = MockProgress();
    when(() => progress.complete(any())).thenAnswer((_) {
      final message = _.positionalArguments.elementAt(0) as String?;
      if (message != null) progressLogs.add(message);
    });
    when(() => logger.progress(any())).thenReturn(progress);
  });

  group('CreateSubCommand', () {
    late Template template;
    late MockBundle bundle;

    setUp(() {
      bundle = MockBundle();
      when(() => bundle.name).thenReturn('test');
      when(() => bundle.description).thenReturn('Test bundle');
      when(() => bundle.version).thenReturn('<bundleversion>');
      template = MockTemplate();
      when(() => template.name).thenReturn('test');
      when(() => template.bundle).thenReturn(bundle);
      when(() => template.onGenerateComplete(any(), any())).thenAnswer(
        (_) async {},
      );
    });

    group('can be instantiated', () {
      test('with default options', () {
        final command = _TestCreateSubCommand(
          template: template,
          analytics: analytics,
          logger: logger,
          generatorFromBundle: null,
          generatorFromBrick: null,
        );
        expect(command.name, isNotNull);
        expect(command.description, isNotNull);
        expect(command.argParser.options, {
          'help': isA<Option>(),
          'output-directory': isA<Option>()
              .having((o) => o.isSingle, 'isSingle', true)
              .having((o) => o.abbr, 'abbr', 'o')
              .having((o) => o.defaultsTo, 'defaultsTo', null)
              .having((o) => o.mandatory, 'mandatory', false),
          'desc': isA<Option>()
              .having((o) => o.isSingle, 'isSingle', true)
              .having((o) => o.abbr, 'abbr', null)
              .having(
                (o) => o.defaultsTo,
                'defaultsTo',
                'A Very Good Project created by Very Good CLI.',
              )
              .having((o) => o.mandatory, 'mandatory', false),
        });
        expect(command.argParser.commands, isEmpty);
      });
    });
    group('parsing of options', () {
      test('parses desc and project name', () async {
        final hooks = MockGeneratorHooks();
        final generator = MockMasonGenerator();

        when(() => generator.hooks).thenReturn(hooks);
        when(
          () => hooks.preGen(
            vars: any(named: 'vars'),
            onVarsChanged: any(named: 'onVarsChanged'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => generator.generate(
            any(),
            vars: any(named: 'vars'),
            logger: any(named: 'logger'),
          ),
        ).thenAnswer((_) async {
          return generatedFiles;
        });

        final command = _TestCreateSubCommand(
          template: template,
          analytics: analytics,
          logger: logger,
          generatorFromBundle: (_) async => throw Exception('oops'),
          generatorFromBrick: (_) async => generator,
        );

        final runner = _TestCommandRunner(command: command);

        await runner.run(['test', 'test_project', '--desc', 'test_desc']);
      });
      group('validating project name', () {});
      group('generates template', () {});
    });
  });
  group('OrgName', () {});
  group('MultiTemplates', () {});
}
