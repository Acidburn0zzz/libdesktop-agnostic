/* 
 * Tests the Color class, plus its interaction with the Config interface.
 *
 * Copyright (C) 2009 Mark Lee <libdesktop-agnostic@lazymalevolence.com>
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
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 *
 * Author : Mark Lee <libdesktop-agnostic@lazymalevolence.com>
 */

using DesktopAgnostic;

int main (string[] args)
{
  Config.Backend cfg = config_get_default ("test-color.schema-ini");
  try
  {
    Color green = new Color.from_string ("green");
    assert (green.alpha == 0);
    message ("green = %s", green.to_string ());
  }
  catch (ColorParseError err)
  {
    critical (err.message);
  }
  Color clr = (Color)cfg.get_value (Config.GROUP_DEFAULT, "color").get_object ();
  message ("cfg color = %s", clr.to_string ());
  return 0;
}

// vim: set et ts=2 sts=2 sw=2 ai :
