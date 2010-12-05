/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
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

namespace Synapse
{
  errordomain DesktopFileError
  {
    UNINTERESTING_ENTRY
  }

  public class DesktopFileInfo: Object
  {
    // registered environments from http://standards.freedesktop.org/menu-spec/latest
    [Flags]
    public enum EnvironmentType
    {
      GNOME = 1 << 0,
      KDE   = 1 << 1,
      LXDE  = 1 << 2,
      ROX   = 1 << 3,
      XFCE  = 1 << 4,
      OLD   = 1 << 5,

      ALL   = 0x3F
    }
    
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
    
    public EnvironmentType show_in { get; set; default = EnvironmentType.ALL; }

    private static const string GROUP = "Desktop Entry";

    public DesktopFileInfo.for_keyfile (string path, KeyFile keyfile)
    {
      Object (filename: path);

      init_from_keyfile (keyfile);
    }
    
    private EnvironmentType parse_environments (string[] environments)
    {
      EnvironmentType result = 0;
      foreach (unowned string env in environments)
      {
        string env_up = env.up ();
        switch (env_up)
        {
          case "GNOME": result |= EnvironmentType.GNOME; break;
          case "KDE": result |= EnvironmentType.KDE; break;
          case "LXDE": result |= EnvironmentType.LXDE; break;
          case "XFCE": result |= EnvironmentType.XFCE; break;
          case "ROX": result |= EnvironmentType.ROX; break;
          case "OLD": result |= EnvironmentType.OLD; break;
          default: warning ("%s is not understood", env); break;
        }
      }
      return result;
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
        if (keyfile.has_key (GROUP, "OnlyShowIn"))
        {
          show_in = parse_environments (keyfile.get_string_list (GROUP, 
                                                                 "OnlyShowIn"));
        }
        else if (keyfile.has_key (GROUP, "NotShowIn"))
        {
          var not_show = parse_environments (keyfile.get_string_list (GROUP,
                                                                  "NotShowIn"));
          show_in = EnvironmentType.ALL ^ not_show;
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

    private Gee.List<FileMonitor> directory_monitors;
    private Gee.List<DesktopFileInfo> all_desktop_files;
    private Gee.List<DesktopFileInfo> non_hidden_desktop_files;
    private Gee.Map<unowned string, Gee.List<DesktopFileInfo> > mimetype_map;
    private Gee.Map<string, Gee.List<DesktopFileInfo> > exec_map;
    
    construct
    {
      instance = this;
      
      directory_monitors = new Gee.ArrayList<FileMonitor> ();
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
      get_environment_type ();
      yield load_all_desktop_files ();
      
      initialized = true;
      initialization_done ();
    }
    
    private DesktopFileInfo.EnvironmentType session_type =
      DesktopFileInfo.EnvironmentType.GNOME;
    
    private void get_environment_type ()
    {
      unowned string? session_var = Environment.get_variable ("DESKTOP_SESSION");
      
      if (session_var == null) return;
      
      string session = session_var.down ();
      
      if (session.has_prefix ("kde"))
        session_type = DesktopFileInfo.EnvironmentType.KDE;
      else if (session.has_prefix ("gnome"))
        session_type = DesktopFileInfo.EnvironmentType.GNOME;
      else if (session.has_prefix ("lx"))
        session_type = DesktopFileInfo.EnvironmentType.LXDE;
      else if (session.has_prefix ("xfce"))
        session_type = DesktopFileInfo.EnvironmentType.XFCE;
      else if (session.has_prefix ("rox"))
        session_type = DesktopFileInfo.EnvironmentType.ROX;
      else
        warning ("Desktop session type is not recognized, assuming GNOME.");
    }
  
    private async void load_all_desktop_files ()
    {
      string[] data_dirs = Environment.get_system_data_dirs ();
      data_dirs += Environment.get_user_data_dir ();

      Gee.Set<File> desktop_file_dirs = new Gee.HashSet<File> ();

      foreach (unowned string data_dir in data_dirs)
      {
        string dir_path = Path.build_filename (data_dir, "applications", null);
        try
        {
          // FIXME: monitor the directories for changes
          var directory = File.new_for_path (dir_path);
          if (!directory.query_exists ()) continue; // FIXME: async
          desktop_file_dirs.add (directory);
          var enumerator = yield directory.enumerate_children_async (
            FILE_ATTRIBUTE_STANDARD_NAME, 0, 0);
          var files = yield enumerator.next_files_async (1024, 0);
          foreach (var f in files)
          {
            unowned string name = f.get_name ();
            // ignore ourselves
            if (name.has_suffix ("synapse.desktop")) continue;
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
      
      create_indices ();
      
      directory_monitors = new Gee.ArrayList<FileMonitor> ();
      foreach (File d in desktop_file_dirs)
      {
        FileMonitor monitor = d.monitor_directory (0, null);
        monitor.changed.connect (this.desktop_file_directory_changed);
        directory_monitors.add (monitor);
      }
    }
    
    private uint timer_id = 0;

    public signal void reload_started ();
    public signal void reload_done ();

    private void desktop_file_directory_changed ()
    {
      reload_started ();
      if (timer_id != 0)
      {
        Source.remove (timer_id);
      }
      
      timer_id = Timeout.add (5000, () =>
      {
        timer_id = 0;
        reload_desktop_files ();
        return false;
      });
    }
    
    private async void reload_desktop_files ()
    {
      debug ("Reloading desktop files...");
      all_desktop_files.clear ();
      non_hidden_desktop_files.clear ();
      yield load_all_desktop_files ();

      reload_done ();
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
            if (!dfi.is_hidden && session_type in dfi.show_in)
            {
              non_hidden_desktop_files.add (dfi);
            }
          }
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
    }
    
    private void create_indices ()
    {
      // create mimetype maps
      mimetype_map =
        new Gee.HashMap<unowned string, Gee.List<DesktopFileInfo> > ();
      // and exec map
      exec_map =
        new Gee.HashMap<string, Gee.List<DesktopFileInfo> > ();

      Regex exec_re;
      try
      {
        exec_re = new Regex ("%[fFuU]");
      }
      catch (Error err)
      {
        critical ("%s", err.message);
        return;
      }

      foreach (var dfi in all_desktop_files)
      {
        var exec = exec_re.replace_literal (dfi.exec, -1, 0, "").strip ();
        // update exec map
        Gee.List<DesktopFileInfo>? exec_list = exec_map[exec];
        if (exec_list == null)
        {
          exec_list = new Gee.ArrayList<DesktopFileInfo> ();
          exec_map[exec] = exec_list;
        }
        exec_list.add (dfi);

        // update mimetype map
        if (dfi.mime_types == null) continue;
        
        foreach (unowned string mime_type in dfi.mime_types)
        {
          Gee.List<DesktopFileInfo>? list = mimetype_map[mime_type];
          if (list == null)
          {
            list = new Gee.ArrayList<DesktopFileInfo> ();
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
    
    public Gee.List<DesktopFileInfo> get_desktop_files_for_exec (string exec)
    {
      return exec_map[exec] ?? new Gee.ArrayList<DesktopFileInfo> ();
    }
  }
}

