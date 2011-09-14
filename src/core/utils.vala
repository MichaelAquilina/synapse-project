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
  //[CCode (gir_namespace = "SynapseUtils", gir_version = "1.0")]
  namespace Utils
  {
    /* Make sure setlocale was called before calling this function
     *   (Gtk.init calls it automatically)
     */
    public static string? remove_accents (string input)
    {
      string? result;
      unowned string charset;
      GLib.get_charset (out charset);
      try
      {
        result = GLib.convert (input, input.length,
                               "US-ASCII//TRANSLIT", charset);
        // no need to waste cpu cycles if the input is the same
        if (input == result) return null;
      }
      catch (ConvertError err)
      {
        result = null;
      }

      return result;
    }
    
    public static string? remove_last_unichar (string input)
    {
      long char_count = input.char_count ();

      int len = input.index_of_nth_char (char_count - 1);
      return input.substring (0, len);
    }
    
    public static async bool query_exists_async (GLib.File f)
    {
      bool exists;
      try
      {
        yield f.query_info_async (FILE_ATTRIBUTE_STANDARD_TYPE, 0, 0, null);
        exists = true;
      }
      catch (Error err)
      {
        exists = false;
      }

      return exists;
    }
    
    public string extract_type_name (Type obj_type)
    {
      string obj_class = obj_type.name ();
      if (obj_class.has_prefix ("Synapse")) return obj_class.substring (7);
      
      return obj_class;
    }
    
    public class Logger
    {
      protected const string RED = "\x1b[31m";
      protected const string GREEN = "\x1b[32m";
      protected const string YELLOW = "\x1b[33m";
      protected const string BLUE = "\x1b[34m";
      protected const string MAGENTA = "\x1b[35m";
      protected const string CYAN = "\x1b[36m";
      protected const string RESET = "\x1b[0m";

      private static bool initialized = false;
      private static bool show_debug = false;

      private static void log_internal (Object? obj, LogLevelFlags level, string format, va_list args)
      {
        if (!initialized) initialize ();
        string desc = "";
        if (obj != null)
        {
          string obj_class = extract_type_name (obj.get_type ());
          desc = "%s[%s]%s ".printf (MAGENTA, obj_class, RESET);
        }
        logv ("Synapse", level, desc + format, args);
      }
      
      private static void initialize ()
      {
        var levels = LogLevelFlags.LEVEL_DEBUG | LogLevelFlags.LEVEL_INFO |
            LogLevelFlags.LEVEL_WARNING | LogLevelFlags.LEVEL_CRITICAL |
            LogLevelFlags.LEVEL_ERROR;

        string[] domains = 
        {
          "Synapse",
          "Gtk",
          "Gdk",
          "GLib",
          "GLib-GObject",
          "Pango",
          "GdkPixbuf",
          "GLib-GIO",
          "GtkHotkey"
        };
        foreach (unowned string domain in domains)
        {
          Log.set_handler (domain, levels, handler);
        }
        Log.set_handler (null, levels, handler);

        show_debug = Environment.get_variable ("SYNAPSE_DEBUG") != null;
        initialized = true;
      }
      
      public static bool debug_enabled ()
      {
        if (!initialized) initialize ();
        return show_debug;
      }
      
      public static void log (Object? obj, string format, ...)
      {
        var args = va_list ();
        log_internal (obj, LogLevelFlags.LEVEL_INFO, format, args);
      }

      [Diagnostics]
      public static void debug (Object? obj, string format, ...)
      {
        var args = va_list ();
        log_internal (obj, LogLevelFlags.LEVEL_DEBUG, format, args);
      }

      public static void warning (Object? obj, string format, ...)
      {
        var args = va_list ();
        log_internal (obj, LogLevelFlags.LEVEL_WARNING, format, args);
      }

      public static void error (Object? obj, string format, ...)
      {
        var args = va_list ();
        log_internal (obj, LogLevelFlags.LEVEL_ERROR, format, args);
      }
      
      protected static void handler (string? domain, LogLevelFlags level, string msg)
      {
        string header;
        string domain_str = "";
        if (domain != null && domain != "Synapse") domain_str = domain + "-";
        string cur_time = TimeVal ().to_iso8601 ().substring (11, 15);
        if (level == LogLevelFlags.LEVEL_DEBUG)
        {
          if (!show_debug && domain_str == "") return;
          header = @"$(GREEN)[$(cur_time) $(domain_str)Debug]$(RESET)";
        }
        else if (level == LogLevelFlags.LEVEL_INFO)
        {
          header = @"$(BLUE)[$(cur_time) $(domain_str)Info]$(RESET)";
        }
        else if (level == LogLevelFlags.LEVEL_WARNING)
        {
          header = @"$(RED)[$(cur_time) $(domain_str)Warning]$(RESET)";
        }
        else if (level == LogLevelFlags.LEVEL_CRITICAL || level == LogLevelFlags.LEVEL_ERROR)
        {
          header = @"$(RED)[$(cur_time) $(domain_str)Critical]$(RESET)";
        }
        else
        {
          header = @"$(YELLOW)[$(cur_time)]$(RESET)";
        }

        stdout.printf ("%s %s\n", header, msg);
#if 0
        void* buffer[10];
        int num = Linux.backtrace (&buffer, 10);
        string[] symbols = Linux.backtrace_symbols (buffer, num);
        if (symbols != null)
        {
          for (int i = 0; i < num; i++) stdout.printf ("%s\n", symbols[i]);
        }
#endif
      }
    }

    public class FileInfo
    {
      private static string interesting_attributes;
      static construct
      {
        interesting_attributes =
          string.join (",", FILE_ATTRIBUTE_STANDARD_TYPE,
                            FILE_ATTRIBUTE_STANDARD_IS_HIDDEN,
                            FILE_ATTRIBUTE_STANDARD_IS_BACKUP,
                            FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME,
                            FILE_ATTRIBUTE_STANDARD_ICON,
                            FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE,
                            FILE_ATTRIBUTE_THUMBNAIL_PATH,
                            null);
      }

      public string uri;
      public string parse_name;
      public QueryFlags file_type;
      public UriMatch? match_obj;
      private bool initialized;
      private Type match_obj_type;

      public FileInfo (string uri, Type obj_type)
      {
        assert (obj_type.is_a (typeof (UriMatch)));
        this.uri = uri;
        this.match_obj = null;
        this.match_obj_type = obj_type;
        this.initialized = false;
        this.file_type = QueryFlags.UNCATEGORIZED;

        var f = File.new_for_uri (uri);
        this.parse_name = f.get_parse_name ();
      }
      
      public bool is_initialized ()
      {
        return this.initialized;
      }
      
      public async void initialize ()
      {
        initialized = true;
        var f = File.new_for_uri (uri);
        try
        {
          var fi = yield f.query_info_async (interesting_attributes,
                                             0, 0, null);
          if (fi.get_file_type () == FileType.REGULAR &&
              !fi.get_is_hidden () &&
              !fi.get_is_backup ())
          {
            match_obj = (UriMatch) Object.new (match_obj_type,
              "thumbnail-path", fi.get_attribute_byte_string (FILE_ATTRIBUTE_THUMBNAIL_PATH),
              "icon-name", fi.get_icon ().to_string (),
              "uri", uri,
              "title", fi.get_display_name (),
              "description", f.get_parse_name (),
              "match-type", MatchType.GENERIC_URI,
              null
            );
            
            // let's determine the file type
            unowned string mime_type = 
              fi.get_attribute_string (FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);
            if (ContentType.is_unknown (mime_type))
            {
              file_type = QueryFlags.UNCATEGORIZED;
            }
            else if (ContentType.is_a (mime_type, "audio/*"))
            {
              file_type = QueryFlags.AUDIO;
            }
            else if (ContentType.is_a (mime_type, "video/*"))
            {
              file_type = QueryFlags.VIDEO;
            }
            else if (ContentType.is_a (mime_type, "image/*"))
            {
              file_type = QueryFlags.IMAGES;
            }
            else if (ContentType.is_a (mime_type, "text/*"))
            {
              file_type = QueryFlags.DOCUMENTS;
            }
            // FIXME: this isn't right
            else if (ContentType.is_a (mime_type, "application/*"))
            {
              file_type = QueryFlags.DOCUMENTS;
            }

            match_obj.file_type = file_type;
            match_obj.mime_type = mime_type;
          }
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
      
      public async bool exists ()
      {
        var f = File.new_for_uri (uri);
        bool result = yield query_exists_async (f);
        
        return result;
      }
    }
  }
}

