=begin
  rvdump�̕ϊ�����
=end

require 'fileutils'

module Rvdump 
module Converter
  OUTPUT_EXT = 'dat'

  # �w�肳�ꂽ�t�H���_�ɂ���t�@�C���̂������O���X�g�ɂ�����̈ȊO�̑S�Ă�ϊ�����
  # @param [String] input_path �Ώۂ̃t�@�C�����u���ꂽ�t�H���_
  # @param [String] output_path �ϊ������t�@�C�����쐬����t�H���_
  # @param [Array<String>] excludes �������X�g
  def self.convert_all(input_path, output_path, excludes)
    # �f�B���N�g���ꗗ����t�@�C�����X�g���쐬����
    filelist = Dir.chdir(input_path) {
      Dir.glob("**/*").select {|filename|
        next false unless File.file?(filename)
        next false if excludes.any? {|pattern| filename.match(Regexp.compile(pattern)) }
        true
      }
    }
    convert_files(input_path, output_path, filelist)
  end

  # �t�@�C�����X�g�ɂ���t�@�C����S�ĕϊ�����
  # @param [String] input_path �Ώۂ̃t�@�C�����u���ꂽ�t�H���_
  # @param [String] output_path �ϊ������t�@�C�����쐬����t�H���_
  # @param [Array<String>] files �ϊ�����Ώۂ̃t�@�C��
  def self.convert_files(input_path, output_path, files)
    # ���X�g�ɂ���t�@�C�����ꂼ���ϊ�����
    files.each do |file|
      dirname = File.dirname(file)
      basename = File.basename(file, ".*")
      convert("#{input_path}/#{file}", output_path, "#{dirname}/#{basename}.#{OUTPUT_EXT}")
    end
  end

  # �w�肳�ꂽ�t�@�C����ϊ�����
  # @param [String] input �ϊ�����t�@�C��
  # @param [String] output_path �ϊ������t�@�C�����쐬����t�H���_
  # @param [String] output_name �ϊ������t�@�C���̃t�@�C����(output_path����̑��΃p�X)
  def self.convert(input, output_path, output_name)
    File.open(input, "r") {|f|
      save("#{output_path}/#{output_name}", f.read)
    }
  end

private
  def self.save(output, data)
    dirname = File.dirname(output)
    FileUtils.mkdir_p(dirname) unless Dir.exist?(dirname)
    File.open(output, "wb") {|f|
      f.write Marshal.dump(data)
    }
  end

end
end

