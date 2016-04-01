/*
 * Copyright (C) 2015 Michael Aquilina <michaelaquilina@gmail.com>

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
 * Authored by Michael Aquilina <michaelaquilina@gmail.com>
 *
 */

namespace Synapse
{
  public class PassPlugin : Object, Activatable, ItemProvider
  {
    private class PassMatch : ActionMatch
    {
      public PassMatch (string password_name)
      {
        Object (title: password_name,
                description: _("Copy decrypted PGP password to clipboard"),
                has_thumbnail: false, icon_name: "dialog-password");
      }

      public override void do_action ()
      {
        Pid child_pid;
        int standard_output;
        int standard_error;

        try
        {
          Process.spawn_async_with_pipes (null,
              {"pass", "-c", this.title},
              null, SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
              null, out child_pid,
              null, out standard_output, out standard_error
          );
          ChildWatch.add (child_pid, (pid, status) => {
            Process.close_pid (pid);

            try
            {
              string message, icon_name;
              if (status == 0) {
                message = _("Copied %s password to clipboard").printf (this.title);
                icon_name = "dialog-password";
              } else {
                message = _("Unable to decrypt %s password").printf (this.title);
                icon_name = "dialog-error";
              }

              var notification = (Notify.Notification) Object.new (
                  typeof (Notify.Notification),
                  summary: _("Synapse - Pass"),
                  body: message,
                  icon_name: icon_name,
                  null
              );
              notification.show ();
            }
            catch (Error err) {
              warning ("%s", err.message);
            }
          });
        }
        catch (SpawnError err) {
          warning ("%s", err.message);
        }
      }
    }

    public bool enabled { get; set; default = true; }

    private File password_store;
    private List<string> passwords;
    private List<FileMonitor> monitors;

    public void activate ()
    {
      password_store = File.new_for_path (
        "%s/.password-store".printf (Environment.get_home_dir ())
      );
      update_passwords ();
    }

    public void deactivate ()
    {
    }

    static void register_plugin ()
    {
      PluginRegistry.get_default ().register_plugin (
        typeof (PassPlugin),
        _("Pass Integration"),
        _("Quickly place passwords from your password store in the clipboard."),
        "dialog-password",
        register_plugin,
        Environment.find_program_in_path ("pass") != null,
        _("pass is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    public bool handles_query (Query query)
    {
      return (QueryFlags.ACTIONS in query.query_type);
    }

    private void update_passwords () {
      foreach (unowned FileMonitor monitor in monitors) {
        monitor.cancel ();
      }
      monitors = null;

      try {
        monitors = activate_monitors (password_store);
      } catch (Error err) {
        warning ("Unable to monitor password directory: %s", err.message);
      }
      try {
        passwords = list_passwords (password_store, password_store);
      } catch (Error err) {
        warning ("Unable to list passwords: %s", err.message);
      }
    }

    private List<FileMonitor> activate_monitors (File directory) throws Error {
      List<FileMonitor> result = new List<FileMonitor> ();

      FileEnumerator enumerator = directory.enumerate_children (
        FileAttribute.STANDARD_NAME + "," +
        FileAttribute.STANDARD_TYPE + "," +
        FileAttribute.STANDARD_IS_HIDDEN,
        FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
        null
      );

      FileMonitor monitor = directory.monitor_directory (FileMonitorFlags.NONE, null);
      monitor.set_rate_limit (500);
      monitor.changed.connect ((src, dest, event) => {
        message ("Detected a change (%s) in password store. Reloading", event.to_string ());
        update_passwords ();
      });
      result.append (monitor);

      FileInfo? info = null;
      while ((info = enumerator.next_file (null)) != null) {
        if (info.get_is_hidden ()) continue;

        File target_file = directory.get_child (info.get_name ());
        if (info.get_file_type () == FileType.DIRECTORY) {
          result.concat (activate_monitors (target_file));
        }
      }

      return result;
    }

    private List<string> list_passwords (File root, File directory) throws Error {
      List<string> result = new List<string> ();

      FileEnumerator enumerator = directory.enumerate_children (
        FileAttribute.STANDARD_NAME + "," +
        FileAttribute.STANDARD_TYPE + "," +
        FileAttribute.STANDARD_CONTENT_TYPE,
        FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
        null
      );

      FileInfo? info = null;
      while ((info = enumerator.next_file (null)) != null) {
        File target_file = directory.get_child (info.get_name ());
        if (info.get_file_type () == FileType.DIRECTORY) {
          result.concat (list_passwords (root, target_file));
        }
        else if (info.get_content_type () == "application/pgp-encrypted") {
          var path = root.get_relative_path (target_file);
          result.prepend (path.replace (".gpg", ""));
        }
      }
      return result;
    }

    public async ResultSet? search (Query query) throws SearchError
    {
      var matchers = Query.get_matchers_for_query (
        query.query_string, 0,
        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS
      );

      var results = new ResultSet ();
      foreach (unowned string password in passwords)
      {
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (password)) {
            results.add (new PassMatch (password), MatchScore.GOOD);
            break;
          }
        }
      }

      // make sure this method is called before returning any results
      query.check_cancellable ();
      if (results.size > 0) {
        return results;
      } else {
        return null;
      }
    }
  }
}
