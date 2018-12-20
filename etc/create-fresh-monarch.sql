-- Copyright (C) 2004-2018  GroundWork Inc.  www.gwos.com
--
--    This program is free software; you can redistribute it and/or modify
--    it under the terms of version 2 of the GNU General Public License
--    as published by the Free Software Foundation and reprinted below;
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program; if not, write to the Free Software
--    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
--
-- 

DROP DATABASE IF EXISTS monarch;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public from monarch;
DROP USER IF EXISTS monarch;
CREATE USER monarch WITH PASSWORD 'gwrk';
CREATE DATABASE monarch TEMPLATE template0 ENCODING='LATIN1' LC_COLLATE='C' LC_CTYPE='C' OWNER=monarch;

-- Set permissions.
GRANT ALL PRIVILEGES ON DATABASE monarch to monarch;
