/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Json;

namespace Synapse
{
  public abstract class ConfigObject : GLib.Object
  {
  }

  public class ConfigService : GLib.Object
  {
    // singleton that can be easily destroyed
    private static unowned ConfigService? instance;
    public static ConfigService get_default ()
    {
      return instance ?? new ConfigService ();
    }

    private ConfigService ()
    {
    }
    
    ~ConfigService ()
    {
      // useless cause the timer takes a reference on self
      if (save_timer_id != 0) save ();
      instance = null;
    }

    private Json.Node root_node;
    private string config_file_name;
    private uint save_timer_id = 0;
    
    construct
    {
      instance = this;
      
      var parser = new Parser ();
      config_file_name = 
        Path.build_filename (Environment.get_user_config_dir (), "synapse",
                             "config.json");
      try
      {
        parser.load_from_file (config_file_name);
        root_node = parser.get_root ().copy ();
        if (root_node.get_node_type () != NodeType.OBJECT)
        {
          root_node = new Json.Node (NodeType.OBJECT);
          root_node.take_object (new Json.Object ());
        }
      }
      catch (Error err)
      {
        root_node = new Json.Node (NodeType.OBJECT);
        root_node.take_object (new Json.Object ());
      }
    }
    
    public ConfigObject get_config (string group, string key, Type config_type)
    {
      unowned Json.Object obj = root_node.get_object ();
      unowned Json.Node group_node = obj.get_member (group);
      if (group_node != null)
      {
        if (group_node.get_node_type () == NodeType.OBJECT)
        {
          unowned Json.Object group_obj = group_node.get_object ();
          unowned Json.Node key_node = group_obj.get_member (key);
          if (key_node != null && key_node.get_node_type () == NodeType.OBJECT)
          {
            var result = Json.gobject_deserialize (config_type, key_node);
            return result as ConfigObject;
          }
        }
      }
      
      return GLib.Object.new (config_type) as ConfigObject;
    }
    
    public void set_config (string group, string key, ConfigObject cfg_obj)
    {
      unowned Json.Object obj = root_node.get_object ();
      if (!obj.has_member (group) || 
          obj.get_member (group).get_node_type () != NodeType.OBJECT)
      {
        // why set_object_member works, but set_member doesn't ?!
        obj.set_object_member (group, new Json.Object ());
      }

      unowned Json.Object group_obj = obj.get_object_member (group);
      // why the hell is this necessary?
      if (group_obj.has_member (key)) group_obj.remove_member (key);

#if VALA_0_12
#else
      unowned
#endif
      Json.Node node = Json.gobject_serialize (cfg_obj);
      group_obj.set_object_member (key, node.get_object ());
      
      if (save_timer_id != 0) Source.remove (save_timer_id);
      // on crap, this takes a reference on self
      save_timer_id = Timeout.add (30000, this.save_timeout);
    }
    
    private bool save_timeout ()
    {
      save_timer_id = 0;
      save ();

      return false;
    }
    
    public void save ()
    {
      if (save_timer_id != 0)
      {
        Source.remove (save_timer_id);
        save_timer_id = 0;
      }
      
      var generator = new Generator ();
      generator.set_root (root_node);

      DirUtils.create_with_parents (Path.get_dirname (config_file_name), 0755);
      generator.to_file (config_file_name);
    }
  }
}

