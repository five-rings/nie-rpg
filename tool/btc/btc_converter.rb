=begin
=end

require 'find'
require 'rexml/document'

module Btc
module Converter

  def self.convert_all(modes, input, output, excludes)
    files = Dir.chdir(input) {
      Dir.glob("**/*.graphml",).select do |filename|
        next false unless File.file?(filename)
        next false if excludes.any? {|pattern| filename.match(Regexp.compile(pattern)) }
        true
      end
    }
    
    files.each do |file|
      convert(modes, file, input, output)
    end

    unless modes.include?(:binary)
      scripts_conf = generate_scripts_conf(output, ["Scripts.conf"])
      File.write("#{output}\\Scripts.conf.rb", scripts_conf)
    end
  end

  def self.convert_files(modes, input, output, filelist, excludes)
    filelist.each do |file|
      convert(modes, file+".graphml", input, output)
    end

    unless modes.include?(:binary)
      scripts_conf = generate_scripts_conf(output, ["Scripts.conf"])
      File.write("#{output}\\Scripts.conf.rb", scripts_conf)
    end
  end

  def self.generate_scripts_conf(output, excludes)
    codes = []
    codes.push "add <<-EOS"
    Dir.chdir(output) {
      Dir.glob("**/*.rb") do |filename|
        next unless File.file?(filename)
        next if excludes.any? {|pattern| filename.match(Regexp.compile(pattern)) }
        dirname = File.dirname(filename)
        basename = File.basename(filename, ".rb")
        entry = "#{dirname}/#{basename}".sub(/^\.\//, "")
        codes.push "  #{entry}"
      end
    }
    codes.push "EOS"
    codes.join("\n")
  end

  def self.convert(modes, file, input, output)
    fullname = input + "/" + file
    unless File.exists?(fullname)
      warn "btc: #{fullname} does not exist"
      return
    end
    dirname = File.dirname(file)
    basename = File.basename(file, ".*")
    unless modes.include?(:binary)
      name = (dirname.capitalize + "/" + basename.capitalize).sub(/^\.\//, "").gsub(/\//, "_")
    end
    nodes, edges = generate_tree(fullname)
    code = generate_code(nodes, edges, name)

    if File.file?(output)
      filename = output
    else
      filename = "#{output}/#{dirname}/#{basename}.rb"
    end

    filepath = File.dirname(filename)
    Dir.mkdir(filepath) unless Dir.exist?(filepath)
    if modes.include?(:binary)
      File.open(filename+".dat", "wb") {|f|
        Marshal.dump(code, f)
      }
    else
      File.write(filename, code)
    end
  end

  def self.generate_tree(input)
    nodes = {}
    edges = []
    
    doc = REXML::Document::new(open(input))
    doc.elements.each('graphml/graph/node') do |node|
      btnode = node.elements['data/y:ShapeNode/y:NodeLabel']
      next unless btnode

      id = node.attributes['id']
      label, *args = btnode.text.split("\n")
      data = node.elements['data[@key="d5"]']
      data = data.text.split("\n") if data

      nodes[id] = {
        :id => id,
        :label => label,
        :args => args,
        :data => data,
      }
    end
    doc.elements.each('graphml/graph/edge') do |edge|
      id = edge.attributes['id']
      s = edge.attributes['source']
      t =  edge.attributes['target']
      edges.push({
        :id => id,
        :source => s,
        :target => t,
      })
    end

    return nodes, edges
  end

  def self.generate_code(nodes, edges, name)
    namespace = name
    
    root_node = nodes.values.find {|node| node[:label] == "Root" }
    return "# Root node is not found" unless root_node

    root_edge = edges.find {|edge| edge[:source] == root_node[:id] }
    return "# Root edge is not found" unless root_edge
    
    codes = []
    if namespace
      codes.push      "module BehaviorTree"
      codes.push      "module #{namespace}"
      codes.push      "  module #{root_node[:label]}"
      codes.push      "    def layout_node"
    end
    
    codes.concat generate_code_by_edge(nodes, edges, root_edge, 0)

    if namespace
      codes.push      "    end"
      codes.push      "  end"
      codes.push      "end"
      codes.push      "end"
    end
    codes.join("\n")
  end

  def self.generate_code_by_edge(nodes, edges, edge, indent_level, chained = false)
    return [] unless edge

    codes = []
    node = nodes[edge[:target]]
    codes.push generate_code_join_node(node, indent_level, chained)
    next_edges, edges = edges.partition do |edge|
      edge[:source] == node[:id]
    end
    
    if next_edges.size >= 2
      indent = "  " * indent_level
      codes.push "      #{indent}.instance_eval {"
      next_edges.each do |edge|
        codes.concat generate_code_by_edge(nodes, edges, edge, indent_level+1)
      end
      codes.push "      #{indent}}"
    elsif next_edges.size > 0
      codes.concat generate_code_by_edge(nodes, edges, next_edges.first, indent_level, true)
    end

    codes
  end

  def self.generate_code_join_node(node, indent_level = 0, chained = false)
    chain = chained ? "." : ""
    indent = "  " * indent_level
    case node[:label]
    when "Conditional"
      case node[:args][0]
      when "", nil, /^#/
        "      #{indent}#{chain}join_node(#{node[:label]}, proc { #{data_to_script(node[:data], 'false')} })"
      when /^:\w+\?/
          "      #{indent}#{chain}join_node(#{node[:label]}, (importer.method(#{node[:args][0]}) rescue proc { false }))"
      else
          "      #{indent}#{chain}join_node(#{node[:label]}, proc { #{args_to_parameter(node[:args])} })"
      end
    when "Importer"
      "      #{indent}#{chain}join_node(#{node[:label]}, :#{node[:args][0]})"
    when "AdHocAction"
      "      #{indent}#{chain}join_node(#{node[:label]}) { #{data_to_script(node[:data])} }"
    else
      if node[:args].empty?
        "      #{indent}#{chain}join_node(#{node[:label]})"
      else
        "      #{indent}#{chain}join_node(#{node[:label]}, #{args_to_parameter(node[:args])})"
      end
    end
  end

  def self.data_to_script(data, default = "")
    data.join(';')
  rescue
    default
  end
  
  def self.args_to_parameter(args)
    args.map {|a|
      a.gsub(/(:\w+)/) { "context[#{$1}]" }
    }.join(',')
  end

end
end

