$:.unshift File.expand_path('../lib', __FILE__)

require 'persie/version'

Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.name              = 'persie'
  s.version           = Persie::VERSION
  s.license           = 'MIT'
  s.date              = '2014-06-18'

  s.summary     = "电子书制作工具"
  s.description = "使用 AsciiDoc 编写书籍内容，通过 persie 将其转换成 PDF，ePub 和 Mobi 格式电子书。"

  s.authors  = ["Andor Chen"]
  s.email    = 'andor.chen.27@gmail.com'
  s.homepage = 'https://github.com/AndorChen/persie'

  s.require_paths = %w[lib]
  s.executables = ["persie"]
  s.files = `git ls-files`.split($/)
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})

  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.md LICENSE]

  s.add_runtime_dependency('thor',         '0.19.1')
  s.add_runtime_dependency('rouge',        '1.6.2')
  s.add_runtime_dependency('gepub',        '0.6.9.2')
  s.add_runtime_dependency('nokogiri',     '1.6.3.1')
  s.add_runtime_dependency('asciidoctor',  '1.5.0')

  s.add_development_dependency('rake',     '~> 10.3.2')
  s.add_development_dependency('minitest', '~> 5.3.5')
end
