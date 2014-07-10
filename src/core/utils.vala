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
  [CCode (gir_namespace = "SynapseUtils", gir_version = "1.0")]
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
        yield f.query_info_async (FileAttribute.STANDARD_TYPE, 0, 0, null);
        exists = true;
      }
      catch (Error err)
      {
        exists = false;
      }

      return exists;
    }

    public static void open_uri (string uri)
    {
      var f = File.new_for_uri (uri);
      try
      {
        var app_info = f.query_default_handler (null);
        List<File> files = new List<File> ();
        files.prepend (f);
        var display = Gdk.Display.get_default ();
        app_info.launch (files, display.get_app_launch_context ());
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
    }

    public static string extract_type_name (Type obj_type)
    {
      string obj_class = obj_type.name ();
      if (obj_class.has_prefix ("Synapse")) return obj_class.substring (7);

      return obj_class;
    }

    /**
     * A logging class to display all console messages in a nice colored format.
     * Adapated source from plank (by Robert Dyer)
     */
    public class Logger
    {
      public enum LogLevel
      {
        DEBUG,
        INFO,
        WARN,
        ERROR,
        FATAL,
      }

      enum ConsoleColor
      {
        BLACK,
        RED,
        GREEN,
        YELLOW,
        BLUE,
        MAGENTA,
        CYAN,
        WHITE,
      }

      class LogMessage : GLib.Object
      {
        public LogLevel Level { get; construct; }
        public string Message { get; construct; }

        public LogMessage (LogLevel level, string message)
        {
          GLib.Object (Level : level, Message : message);
        }
      }

      /**
       * The current log level.  Controls what log messages actually appear on the console.
       */
      public static LogLevel DisplayLevel { get; set; default = LogLevel.WARN; }

      static Object? queue_lock = null;

      static Gee.ArrayList<LogMessage> log_queue;
      static bool is_writing;

      static Regex? re = null;

      Logger ()
      {
      }

      /**
       * Initializes the logger for the application.
       */
      public static void initialize ()
      {
        is_writing = false;
        log_queue = new Gee.ArrayList<LogMessage> ();
        try {
          re = new Regex ("""[(]?.*?([^/]*?)(\.2)?\.vala(:\d+)[)]?:\s*(.*)""");
        } catch { }

        DisplayLevel = LogLevel.INFO;
        if (Environment.get_variable ("SYNAPSE_DEBUG") != null)
          DisplayLevel = LogLevel.DEBUG;

        Log.set_default_handler (glib_log_func);
      }

      static string format_message (string msg)
      {
        if (re != null && re.match (msg)) {
          var parts = re.split (msg);
          return "[%s%s] %s".printf (parts[1], parts[3], parts[4]);
        }
        return msg;
      }

      static string get_time ()
      {
        var now = new DateTime.now_local ();
        return "%.2d:%.2d:%.2d.%.6d".printf (now.get_hour (), now.get_minute (), now.get_second (), now.get_microsecond ());
      }

      static void write (LogLevel level, string msg)
      {
        if (level < DisplayLevel)
          return;

        if (is_writing) {
          lock (queue_lock)
            log_queue.add (new LogMessage (level, msg));
        } else {
          is_writing = true;

          if (log_queue.size > 0) {
            var logs = log_queue;
            lock (queue_lock)
              log_queue = new Gee.ArrayList<LogMessage> ();

            foreach (var log in logs)
              print_log (log);
          }

          print_log (new LogMessage (level, msg));

          is_writing = false;
        }
      }

      static void print_log (LogMessage log)
      {
        set_color_for_level (log.Level);
        stdout.printf ("[%s %s]", log.Level.to_string ().substring (31), get_time ());

        reset_color ();
        stdout.printf (" %s\n", log.Message);
      }

      static void set_color_for_level (LogLevel level)
      {
        switch (level) {
        case LogLevel.DEBUG:
          set_foreground (ConsoleColor.GREEN);
          break;
        case LogLevel.INFO:
          set_foreground (ConsoleColor.BLUE);
          break;
        case LogLevel.WARN:
        default:
          set_foreground (ConsoleColor.YELLOW);
          break;
        case LogLevel.ERROR:
          set_foreground (ConsoleColor.RED);
          break;
        case LogLevel.FATAL:
          set_background (ConsoleColor.RED);
          set_foreground (ConsoleColor.WHITE);
          break;
        }
      }

      static void reset_color ()
      {
        stdout.printf ("\x001b[0m");
      }

      static void set_foreground (ConsoleColor color)
      {
        set_color (color, true);
      }

      static void set_background (ConsoleColor color)
      {
        set_color (color, false);
      }

      static void set_color (ConsoleColor color, bool isForeground)
      {
        var color_code = color + 30 + 60;
        if (!isForeground)
          color_code += 10;
        stdout.printf ("\x001b[%dm", color_code);
      }

      static void glib_log_func (string? d, LogLevelFlags flags, string msg)
      {
        var domain = "";
        if (d != null)
          domain = "[%s] ".printf (d ?? "");

        var message = msg.replace ("\n", "").replace ("\r", "");
        message = "%s%s".printf (domain, message);

        switch (flags) {
        case LogLevelFlags.LEVEL_CRITICAL:
          write (LogLevel.FATAL, format_message (message));
          break;

        case LogLevelFlags.LEVEL_ERROR:
          write (LogLevel.ERROR, format_message (message));
          break;

        case LogLevelFlags.LEVEL_INFO:
        case LogLevelFlags.LEVEL_MESSAGE:
          write (LogLevel.INFO, format_message (message));
          break;

        case LogLevelFlags.LEVEL_DEBUG:
          write (LogLevel.DEBUG, format_message (message));
          break;

        case LogLevelFlags.LEVEL_WARNING:
        default:
          write (LogLevel.WARN, format_message (message));
          break;
        }
      }
    }

    [Compact]
    private class DelegateWrapper
    {
      public SourceFunc callback;

      public DelegateWrapper (owned SourceFunc cb)
      {
        callback = (owned) cb;
      }
    }
    /*
     * Asynchronous Once.
     *
     * Usage:
     * private AsyncOnce<string> once = new AsyncOnce<string> ();
     * public async void foo ()
     * {
     *   if (!once.is_initialized ()) // not stricly necessary but improves perf
     *   {
     *     if (yield once.enter ())
     *     {
     *       // this block will be executed only once, but the method
     *       // is reentrant; it's also recommended to wrap this block
     *       // in try { } and call once.leave() in finally { }
     *       // if any of the operations can throw an error
     *       var s = yield get_the_string ();
     *       once.leave (s);
     *     }
     *   }
     *   // if control reaches this point the once was initialized
     *   yield do_something_for_string (once.get_data ());
     * }
     */
    public class AsyncOnce<G>
    {
      private enum OperationState
      {
        NOT_STARTED,
        IN_PROGRESS,
        DONE
      }

      private G inner;

      private OperationState state;
      private DelegateWrapper[] callbacks = {};

      public AsyncOnce ()
      {
        state = OperationState.NOT_STARTED;
      }

      public unowned G get_data ()
      {
        return inner;
      }

      public bool is_initialized ()
      {
        return state == OperationState.DONE;
      }

      public async bool enter ()
      {
        if (state == OperationState.NOT_STARTED)
        {
          state = OperationState.IN_PROGRESS;
          return true;
        }
        else if (state == OperationState.IN_PROGRESS)
        {
          yield wait_async ();
        }

        return false;
      }

      public void leave (G result)
      {
        if (state != OperationState.IN_PROGRESS)
        {
          warning ("Incorrect usage of AsyncOnce");
          return;
        }
        state = OperationState.DONE;
        inner = result;
        notify_all ();
      }

      /* Once probably shouldn't have this, but it's useful */
      public void reset ()
      {
        if (state == OperationState.IN_PROGRESS)
        {
          warning ("AsyncOnce.reset() cannot be called in the middle of initialization.");
        }
        else
        {
          state = OperationState.NOT_STARTED;
          inner = null;
        }
      }

      private void notify_all ()
      {
        foreach (unowned DelegateWrapper wrapper in callbacks)
        {
          wrapper.callback ();
        }
        callbacks = {};
      }

      private async void wait_async ()
      {
        callbacks += new DelegateWrapper (wait_async.callback);
        yield;
      }
    }

    public class FileInfo
    {
      private static string interesting_attributes;
      static construct
      {
        interesting_attributes =
          string.join (",", FileAttribute.STANDARD_TYPE,
                            FileAttribute.STANDARD_IS_HIDDEN,
                            FileAttribute.STANDARD_IS_BACKUP,
                            FileAttribute.STANDARD_DISPLAY_NAME,
                            FileAttribute.STANDARD_ICON,
                            FileAttribute.STANDARD_FAST_CONTENT_TYPE,
                            FileAttribute.THUMBNAIL_PATH,
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
              "thumbnail-path", fi.get_attribute_byte_string (FileAttribute.THUMBNAIL_PATH),
              "icon-name", fi.get_icon ().to_string (),
              "uri", uri,
              "title", fi.get_display_name (),
              "description", f.get_parse_name (),
              null
            );

            // let's determine the file type if unavailable the generic "unknown" type is set.
            // On UNIX this is the "application/octet-stream" mimetype
            unowned string mime_type =
              fi.get_attribute_string (FileAttribute.STANDARD_FAST_CONTENT_TYPE) ?? "application/octet-stream";
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

