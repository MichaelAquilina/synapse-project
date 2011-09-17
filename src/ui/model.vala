/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 * Copyright (C) 2010 Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

using Gee;

namespace Synapse.Gui
{
  public class Model : Object
  {
    /* Search strings */
    public string[] query = new string[SearchingFor.COUNT];
    
    /* Result Sets */
    public Gee.List<Match>[] results = new Gee.List<Match>[SearchingFor.COUNT];

    /* Focus */
    public Entry<int, Match>[] focus = new Entry<int, Match>[SearchingFor.COUNT];
    
    /* Category */
    public int selected_category = 0;
    
    /* SearchingFor */
    public SearchingFor searching_for = SearchingFor.SOURCES;
    
    /* returns results[searching_for] != null && .size > 0 */
    public bool has_results ()
    {
      return results[searching_for] != null && results[searching_for].size > 0;
    }

    public Entry<int, Match> get_actual_focus ()
    {
      return focus[searching_for];
    }
    
    public void set_actual_focus (int i)
    {
      focus[searching_for].key = i;
      focus[searching_for].value = results[searching_for].get (i);
    }
    
    public bool needs_target ()
    {
      return focus[SearchingFor.ACTIONS].value != null && 
             focus[SearchingFor.ACTIONS].value.needs_target ();
    }
    
    public void clear (int default_category = -1)
    {
      searching_for = SearchingFor.SOURCES;
      for (int i = 0; i < SearchingFor.COUNT; i++)
      {
        focus[i].key = 0;
        focus[i].value = null;
        results[i] = null;
        query[i] = "";
      }
      if (default_category >= 0)
        selected_category = default_category;
    }
    
    public void clear_searching_for (SearchingFor i, bool clear_query = true)
    {
      // Synapse.Utils.Logger.log (this, "CLEAR: %u", i);
      focus[i].key = 0;
      focus[i].value = null;
      results[i] = null;
      if (clear_query) query[i] = "";
    }
    
    construct
    {
      for (int i = 0; i < SearchingFor.COUNT; i++)
      {
        focus[i] = new Entry<int, Match> ();
      }
      clear ();
    }
  }
}
