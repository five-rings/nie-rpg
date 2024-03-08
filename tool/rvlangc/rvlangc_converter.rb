=begin
  rvlangc�̕ϊ�����
=end

require 'roo'

module Rvlangc
module Converter
  OUTPUT_EXT = 'dat'
  class InvalidIdError < StandardError; end

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
  # @param [String] �ϊ�����t�@�C��
  # @param [String] output_path �ϊ������t�@�C�����쐬����t�H���_
  # @param [String] output_name �ϊ������t�@�C���̃t�@�C����(output_path����̑��΃p�X)
  def self.convert(input, output_path, output_name)
    messages = { nil => {} }
    roo = Roo::Spreadsheet.open(input)

    roo.sheets.each do |sheet|
      roo.default_sheet = sheet
     
      # �f�[�^��`�����Ă���s���T��
      row_def_field = roo.first_row
      col_id_field = 1.upto(roo.last_column).find {|col_index|
        roo.cell(row_def_field, col_index).nil?.!
      }
      
      col_default_field = col_id_field + 1
      col_lang_field_start = col_default_field + 1

      # �ݒ肳��Ă��錾��p�Ƀo�b�t�@���쐬
      col_lang_field_start.upto(roo.last_column).each do |col_index|
        lang = roo.cell(row_def_field, col_index)
        messages[lang] ||= {} if lang
      end

      # �e�L�X�g�f�[�^�����ꂲ�ƂɎ��o���Ă���
      (row_def_field + 1).upto(roo.last_row).each do |row_index|
        begin
          id = roo.cell(row_index, col_id_field).intern
        rescue
          raise InvalidIdError, "Invalid id.`#{id}' specified at (#{row_index}, #{col_id_field})"
        end

        raise InvalidIdError, "Id.`#{id}' is duplicated at (#{row_index}, #{col_id_field})" if messages[nil].has_key?(id)
        
        # �f�t�H���g
        data = roo.cell(row_index, col_default_field)
        messages[nil].store id, data if data
        # �e����
        col_lang_field_start.upto(roo.last_column).each do |col_index|
          lang = roo.cell(row_def_field, col_index)
          next unless lang
          data = roo.cell(row_index, col_index)
          messages[lang].store id, data if data
        end
      end
    end

    messages.each do |lang, message|
      if lang
        output = "#{output_path}/#{lang}/#{output_name}"
      else
        output = "#{output_path}/#{output_name}"
      end
      save(output, message)
    end
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

