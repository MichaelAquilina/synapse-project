/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  errordomain DesktopFileError
  {
    UNINTERESTING_ENTRY
  }

  public class DesktopFileInfo: Object
  {
    public string name { get; construct set; }
    public string comment { get; set; default = ""; }
    public string icon_name { get; construct set; default = ""; }

    public bool needs_terminal { get; set; default = false; }
    public string filename { get; construct set; }

    public string exec { get; set; }

    public bool is_hidden { get; private set; default = false; }
    public bool is_valid { get; private set; default = true; }

    public string[] mime_types = null;
    
    private string? name_folded = null;
    public unowned string get_name_folded ()
    {
      if (name_folded == null) name_folded = name.casefold ();
      return name_folded;
    }

    private static const string GROUP = "Desktop Entry";

    public DesktopFileInfo.for_keyfile (string path, KeyFile keyfile)
    {
      Object (filename: path);

      init_from_keyfile (keyfile);
    }

    private void init_from_keyfile (KeyFile keyfile)
    {
      try
      {
        if (keyfile.get_string (GROUP, "Type") != "Application")
        {
          throw new DesktopFileError.UNINTERESTING_ENTRY ("Not Application-type desktop entry");
        }

        name = keyfile.get_locale_string (GROUP, "Name");
        exec = keyfile.get_string (GROUP, "Exec");

        // check for hidden desktop files
        if (keyfile.has_key (GROUP, "Hidden") &&
          keyfile.get_boolean (GROUP, "Hidden"))
        {
          is_hidden = true;
        }
        if (keyfile.has_key (GROUP, "NoDisplay") &&
          keyfile.get_boolean (GROUP, "NoDisplay"))
        {
          is_hidden = true;
        }
        if (keyfile.has_key (GROUP, "Comment"))
        {
          comment = keyfile.get_locale_string (GROUP, "Comment");
        }
        if (keyfile.has_key (GROUP, "Icon"))
        {
          icon_name = keyfile.get_locale_string (GROUP, "Icon");
          if (!Path.is_absolute (icon_name) &&
              (icon_name.has_suffix (".png") ||
              icon_name.has_suffix (".svg") ||
              icon_name.has_suffix (".xpm")))
          {
            icon_name = icon_name.ndup (icon_name.size () - 4);
          }
        }
        if (keyfile.has_key (GROUP, "MimeType"))
        {
          mime_types = keyfile.get_string_list (GROUP, "MimeType");
        }
        if (keyfile.has_key (GROUP, "Terminal"))
        {
          needs_terminal = keyfile.get_boolean (GROUP, "Terminal");
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
        is_valid = false;
      }
    }
  }

  public class DesktopFileService : Object
  {
    private static unowned DesktopFileService? instance;
    public bool initialized { get; private set; default = false; }

    // singleton that can be easily destroyed
    public static DesktopFileService get_default ()
    {
      return instance ?? new DesktopFileService ();
    }

    private DesktopFileService ()
    {
    }
    
    private Gee.List<DesktopFileInfo> all_desktop_files;
    private Gee.List<DesktopFileInfo> non_hidden_desktop_files;
    private Gee.Map<unowned string, Gee.List<DesktopFileInfo> > mimetype_map;
    
    construct
    {
      instance = this;
      
      all_desktop_files = new Gee.ArrayList<DesktopFileInfo> ();
      non_hidden_desktop_files = new Gee.ArrayList<DesktopFileInfo> ();

      initialize ();
    }
    
    ~DesktopFileService ()
    {
      instance = null;
    }
   
    public signal void initialization_done ();
    
    private async void initialize ()
    {
      yield load_all_desktop_files ();
      
      initialized = true;
      initialization_done ();
    }
  
    private async void load_all_desktop_files ()
    {
      string[] data_dirs = Environment.get_system_data_dirs ();
      data_dirs += Environment.get_user_data_dir ();

      foreach (unowned string data_dir in data_dirs)
      {
        string dir_path = Path.build_filename (data_dir, "applications", null);
        try
        {
          // FIXME: monitor the directories for changes
          var directory = File.new_for_path (dir_path);
          if (!directory.query_exists ()) continue; // FIXME: async
          var enumerator = yield directory.enumerate_children_async (
            FILE_ATTRIBUTE_STANDARD_NAME, 0, 0);
          var files = yield enumerator.next_files_async (1024, 0);
          foreach (var f in files)
          {
            unowned string name = f.get_name ();
            if (name.has_suffix (".desktop"))
            {
              yield load_desktop_file (directory.get_child (name));
            }
          }
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
      
      create_indexes ();
    }

    private async void load_desktop_file (File file)
    {
      try
      {
        size_t len;
        string contents;
        bool success = yield file.load_contents_async (null, 
                                                       out contents, out len);
        if (success)
        {
          var keyfile = new KeyFile ();
          keyfile.load_from_data (contents, len, 0);
          var dfi = new DesktopFileInfo.for_keyfile (file.get_path (), keyfile);
          if (dfi.is_valid)
          {
            all_desktop_files.add (dfi);
            if (!dfi.is_hidden) non_hidden_desktop_files.add (dfi);
          }
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
    }
    
    private void create_indexes ()
    {
      // create mimetype maps
      mimetype_map =
        new Gee.HashMap<unowned string, Gee.List<DesktopFileInfo> > ();
        
      foreach (var dfi in all_desktop_files)
      {
        if (dfi.mime_types == null) continue;
        
        foreach (unowned string mime_type in dfi.mime_types)
        {
          Gee.List<DesktopFileInfo>? list = mimetype_map[mime_type];
          if (list == null)
          {
            list = new Gee.LinkedList<DesktopFileInfo> ();
            mimetype_map[mime_type] = list;
          }
          list.add (dfi);
        }
      }
    }
    
    // retuns desktop files available on the system (without hidden ones)
    public Gee.List<DesktopFileInfo> get_desktop_files ()
    {
      return non_hidden_desktop_files.read_only_view;
    }
    
    // returns all desktop files available on the system (even the ones which
    // are hidden by default)
    public Gee.List<DesktopFileInfo> get_all_desktop_files ()
    {
      return all_desktop_files.read_only_view;
    }
    
    public Gee.List<DesktopFileInfo> get_desktop_files_for_type (string mime_type)
    {
      return mimetype_map[mime_type] ?? new Gee.ArrayList<DesktopFileInfo> ();
    }
  }
}

