process.env.CHROME_BIN = require('puppeteer').executablePath();
const path = require('path');

module.exports = function(config) {
  config.set({
    basePath: '..',
    frameworks: ['jasmine', '@angular-devkit/build-angular'],
    plugins: [
      require('karma-jasmine'),
      require('karma-chrome-launcher'),
      require('karma-junit-reporter'),
      require('karma-coverage-istanbul-reporter'),
      require('@angular-devkit/build-angular/plugins/karma'),
      require('karma-sonarqube-unit-reporter')
    ],
    client: {
      clearContext: false, // leave Jasmine Spec Runner output visible in browser
      captureConsole: Boolean(process.env.KARMA_ENABLE_CONSOLE)
    },
    junitReporter: {
      outputDir: path.join(__dirname, './reports/junit/'),
      outputFile: 'test-results.xml',
      useBrowserName: false,
      suite: '' // Will become the package name attribute in xml testsuite element
    },
    coverageIstanbulReporter: {
      reports: ['html', 'lcovonly', 'text-summary'],
      dir: path.join(__dirname, './reports/coverage'),
      fixWebpackSourcePaths: true
    },
    sonarQubeUnitReporter: {
      sonarQubeVersion: 'LATEST',
      outputFile: 'reports/ut_report.xml',
      useBrowserName: false
    },
    angularCli: {
      environment: 'dev'
    },
    reporters: ['progress', 'sonarqubeUnit', 'junit'],
    port: 9876,
    colors: true,
    // Level of logging, can be: LOG_DISABLE || LOG_ERROR || LOG_WARN || LOG_INFO || LOG_DEBUG
    logLevel: config.LOG_INFO,
    autoWatch: true,
    browsers: ['ChromeHeadless'],
    // Fix for: ChromeHeadless stderr: [0522/051708.014478:FATAL:zygote_host_impl_linux.cc(116)] No usable sandbox!
    customLaunchers: {
      'ChromeHeadless': {
        base: 'Chrome',
        flags: [
          '--headless',
          // Required for Docker version of Puppeteer
          '--no-sandbox',
          '--disable-setuid-sandbox',
          // This will write shared memory files into /tmp instead of /dev/shm,
          // because Docker’s default for /dev/shm is 64MB
          '--disable-dev-shm-usage',
          // Without a remote debugging port, Google Chrome exits immediately.
          '--remote-debugging-port=9222'
        ],
        debug: true
      }
    },
    // End fix
    singleRun: false
  });
}