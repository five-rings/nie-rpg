=begin
=end
module Database
  Itefu::Database.extend self
  
  def load_system_table(database)
    load_rgss3_table(database, :system, :SYSTEM, Database::Table::System)
  end

  def load_actors_table(database)
    load_rgss3_table(database, :actors, :ACTORS, Database::Table::Actors)
  end

  def load_enemies_table(database)
    load_rgss3_table(database, :enemies, :ENEMIES, Database::Table::Enemies)
  end

  def load_classes_table(database)
    load_rgss3_table(database, :classes, :CLASSES, Database::Table::Classes)
  end

  def load_skills_table(database)
    load_rgss3_table(database, :skills, :SKILLS, Database::Table::Skills)
  end

  def load_weapons_table(database)
    load_rgss3_table(database, :weapons, :WEAPONS, Database::Table::Weapons)
  end

  def load_armors_table(database)
    load_rgss3_table(database, :armors, :ARMORS, Database::Table::Armors)
  end

  def load_items_table(database)
    load_rgss3_table(database, :items, :ITEMS, Database::Table::Items)
  end

  def load_states_table(database)
    load_rgss3_table(database, :states, :STATES, Database::Table::States)
  end

class << self
  attr_reader :num_present  # [Fixnum] プレゼントイベントの数

  def precomputing
    database = Itefu::Database.instance

    # プレゼントイベントの数を数える
    @num_present = database.common_events.count {|event|
      event && event.list.find {|command|
        # 冒頭にある注釈だけを確認する
        break unless (command.code == Itefu::Rgss3::Definition::Event::Code::COMMENT ||
                      command.code == Itefu::Rgss3::Definition::Event::Code::COMMENT_SEQUEL)
        # プレゼントだけ数える
        command.parameters[0].start_with?("$present")
      }
    }
  end
end

end
