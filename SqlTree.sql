DROP SCHEMA TreeTest;
CREATE SCHEMA TreeTest;
USE TreeTest;

CREATE TABLE `TreeNode` (
  `keyRoot` VARCHAR(255) NOT NULL,
  `keyNode` VARCHAR(255) NOT NULL,
  `depth` INT UNSIGNED NOT NULL,
  `left` INT UNSIGNED NOT NULL,
  `right` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`keyRoot`, `keyNode`)
);

DROP USER IF EXISTS 'execuser'@'localhost';
DROP USER IF EXISTS 'viewuser'@'localhost';
CREATE OR REPLACE VIEW `TreeTest`.`TreeView` AS SELECT `keyRoot`, `keyNode` `depth` from `TreeNode`;
CREATE USER IF NOT EXISTS 'viewuser'@'localhost' IDENTIFIED BY 'viewuser';
CREATE USER IF NOT EXISTS 'execuser'@'localhost' IDENTIFIED BY 'execuser';

-- Allow the execute user to do the things it needs for the procedures.
GRANT SELECT, INSERT, UPDATE, DELETE ON `TreeTest`.`TreeNode` TO 'execuser'@'localhost';

-- Allow the view user to see the limited version of the tree.
GRANT SELECT ON `TreeTest`.`TreeView` TO 'viewuser'@'localhost';

GRANT EXECUTE ON `TreeTest`.* TO 'viewuser'@'localhost';
GRANT EXECUTE ON `TreeTest`.* TO 'execuser'@'localhost';

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `TreeTest`.`treeDelete`(IN tKeyRoot VARCHAR(255))
BEGIN
  DECLARE result VARCHAR(256) DEFAULT "FAILED";
  DECLARE vDepth INT UNSIGNED;
  SELECT `depth` INTO vDepth FROM TreeNode WHERE `keyRoot` = tKeyRoot AND `depth` = 0;
  IF (vDepth IS NOT NULL) THEN
    DELETE FROM TreeNode WHERE  `keyRoot` = tKeyRoot;
    SET result = "OK";
  END IF;
  SELECT result;
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeDeleteBranch`(IN tKeyRoot VARCHAR(255), IN tKeyNode VARCHAR(255))
BEGIN
  DECLARE result VARCHAR(256) DEFAULT "FAILED";
  DECLARE tmp, vDepth, vLeft, vRight INT UNSIGNED;
  SELECT `depth`, `left`, `right` INTO vDepth, vLeft, vRight FROM TreeNode WHERE `keyRoot` = tKeyRoot AND `keyNode` = tkeyNode;
  IF (vDepth IS NOT NULL) THEN
      SET result = "FAILED, no node found for those values";
  ELSE
    IF (vDepth = 0) THEN
      SET result = "FAILED, atempt to delte tree execuser, use treeDelete(keyRoot) to delete a whole tree";
    ELSEIF (vDepth > 0) THEN
      SELECT (vRight - vLeft + 1) INTO tmp;
      DELETE FROM TreeNode WHERE  `keyRoot` = tKeyRoot AND `left` >- vLeft AND `right` <= vRight;
      UPDATE TreeNode SET `left` = (`left` - tmp) WHERE  `keyRoot` = tKeyRoot AND `left` > vLeft;
      UPDATE TreeNode SET `right` = (`right` - tmp) WHERE  `keyRoot` = tKeyRoot AND `right` > vRight;
      SET result = "OK";
    END IF;
  END IF;
  SELECT result;
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeDeleteAChildElement`(IN tKeyRoot VARCHAR(255), IN tKeyNode VARCHAR(255), IN deleteOnlyLeafs BOOLEAN)
BEGIN
  DECLARE result VARCHAR(256) DEFAULT "FAILED";
  DECLARE vDiff, vDepth, vLeft, vRight INT UNSIGNED;
  SELECT (`right` - `left`), `depth`, `left`, `right` INTO vDiff, vDepth, vLeft, vRight FROM TreeNode WHERE `keyRoot` = tKeyRoot AND `keyNode` = tkeyNode;
  IF (vDepth IS NOT NULL) THEN
      SET result = "FAILED, no node found for those values";
  ELSE
    IF (vDepth = 0) THEN
      SET result = "FAILED, atempt to delte tree execuser, use treeDelete(keyRoot) to delete a whole tree";
    ELSEIF ((TRUE = deleteOnlyLeafs) && (vDiff > 1)) THEN
      SET result = "FAILED, deleteOnlyLeafs is set true but node is not a leaf!";
    ELSE
      UPDATE TreeNode SET  `left` = `left` - 1, `right` = `right` - 1, `depth` = `depth` - 1 WHERE `keyRoot` = tKeyRoot AND `left` > vLeft AND `right` < vRight;
      UPDATE TreeNode SET `left` = `left` - 2 WHERE  `keyRoot` = tKeyRoot AND `left` > vRight;
      UPDATE TreeNode SET `right` = `right` - 2 WHERE  `keyRoot` = tKeyRoot AND `right` > vRight;
      DELETE FROM TreeNode WHERE  `keyRoot` = tKeyRoot AND `keyNode` = tKeyNode;
      SET result = "OK";
    END IF;
  END IF;
  SELECT result;
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeGetAncestors`(IN tKeyRoot VARCHAR(255), IN tKeyNode VARCHAR(255), IN relativeDepth INT UNSIGNED)
BEGIN
  DECLARE tmp, vDepth, vRelativeDepth, vLeft, vRight BIGINT SIGNED;
  SELECT relativeDepth INTO tmp;
  SELECT `depth`, `left`, `right` INTO vDepth, vLeft, vRight FROM TreeNode WHERE `keyRoot` = tKeyRoot AND `keyNode` = tkeyNode;
  SELECT (vDepth - tmp) INTO vRelativeDepth;
  IF (vRelativeDepth < 1) THEN
    SET vRelativeDepth = 0;
  END IF;
  SELECT `keyRoot`, `keyNode`, `depth` FROM TreeNode WHERE `left` < vLeft AND `right` > vRight AND `depth` >= vRelativeDepth;
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeGetDecendents`(IN tKeyRoot VARCHAR(255), IN tKeyNode VARCHAR(255), IN relativeDepth INT UNSIGNED)
BEGIN
  DECLARE vDepth, vLeft, vRight INT UNSIGNED;
  SELECT `depth`, `left`, `right` INTO vDepth, vLeft, vRight FROM TreeNode WHERE `keyRoot` = tKeyRoot AND `keyNode` = tkeyNode;
  SELECT `keyRoot`, `keyNode`, `depth` FROM TreeNode WHERE `left` > vLeft AND `right` < vRight AND `depth` <= (vDepth + relativeDepth);
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeGetLeaves`(IN tKeyRoot VARCHAR(255))
BEGIN
  SELECT `keyNode` FROM TreeNode WHERE `keyRoot` = tKeyRoot AND (`right` - `left`) = 1;
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeGetPeers`(IN tDepth INT UNSIGNED)
BEGIN
  SELECT id FROM TreeTest WHERE `depth` = tDepth;
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeGetRoot`(IN tKeyRoot VARCHAR(255), IN tKeyNode VARCHAR(255))
BEGIN
  SELECT `keyNode` FROM TreeNode WHERE `keyRoot` = tKeyRoot AND `left` = 1 ;
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeNewChildElement`(IN tKeyRoot VARCHAR(255), IN keyNodeParent VARCHAR(255), IN keyNodeNewChild VARCHAR(255))
BEGIN
  DECLARE parentDepth, parentLeft, parentRight INT UNSIGNED;
  SELECT `depth`, `left`, `right` INTO parentDepth, parentLeft, parentRight FROM TreeNode WHERE `keyRoot` = tKeyRoot AND `keyNode` = keyNodeParent;
  UPDATE TreeNode SET `depth` = `depth` + 1 WHERE `keyRoot` = tKeyRoot AND `left` > parentLeft + 1 AND `right` < parentLeft + 2;
  UPDATE TreeNode SET `left` = `left` + 2 WHERE`keyRoot` = tKeyRoot AND  `left` > parentLeft;
  UPDATE TreeNode SET `right` = `right` + 2 WHERE`keyRoot` = tKeyRoot AND  `right` > parentLeft;
  INSERT INTO TreeNode (`keyRoot`, `keyNode`, `depth`, `left`, `right`) VALUES (tkeyRoot, keyNodeNewChild, parentDepth + 1, parentLeft+ 1, parentLeft+ 2);
  SELECT "OK";
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `TreeTest`.`treeNewRootElement`(IN tKeyRoot VARCHAR(255), IN tKeyNode VARCHAR(255))
BEGIN
   INSERT INTO TreeNode (`keyRoot`, `keyNode`, `depth`, `left`, `right`) VALUES (tKeyRoot, tKeyNode, 0, 1, 2);
   SELECT "OK";
END//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE `TreeTest`.`treeNewRootElement` TO 'viewuser'@'localhost';
GRANT EXECUTE ON PROCEDURE `TreeTest`.`treeNewRootElement` TO 'execuser'@'localhost';

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeIsLeaf`(IN tKeyRoot VARCHAR(255), IN tKeyNode VARCHAR(255))
BEGIN
  DECLARE result BOOLEAN DEFAULT FALSE;
  DECLARE vDiff INT UNSIGNED;
  SELECT (`right` - `left`) INTO vDiff FROM TreeNode WHERE  `keyRoot` = tKeyRoot AND `keyNode` = tkeyNode;
  IF(vDiff = 1) THEN
    SET result = TRUE;
  END IF;
  SELECT result;
END//
DELIMITER ;

DELIMITER //
CREATE DEFINER=`execuser`@`localhost` PROCEDURE `treeIsRoot`(IN tKeyRoot VARCHAR(255), IN tKeyNode VARCHAR(255))
BEGIN
  DECLARE result BOOLEAN DEFAULT FALSE;
  DECLARE vLeft INT UNSIGNED;
  SELECT `left` INTO vLeft FROM TreeNode WHERE `keyRoot` = tKeyRoot AND `keyNode` = tkeyNode AND `left` = 1;
  IF(vLeft = 1) THEN
    SET result = TRUE;
  END IF;
  SELECT result;
END//
DELIMITER ;



-- Test insert new Root
CALL treeNewRootElement('A', 'v0');
CALL treeNewRootElement('B', 'v0');
-- SELECT * FROM `TreeNode` ORDER BY `depth`, `left`, `right`;
-- | key |
-- +-----+
-- | A   |
-- | B   |
-- | keyRoot | keyNode | depth | left | right |
-- +---------+---------+-------+------+-------+
-- | A       | v0      |     0 |    1 |     2 |
-- | B       | v0      |     0 |    1 |     2 |

CALL treeNewChildElement('A', 'v0', 'v1');
-- SELECT * FROM `TreeNode` ORDER BY `depth`, `left`, `right`;
-- | keyRoot | keyNode | depth | left | right |
-- +---------+---------+-------+------+-------+
-- | B       | v0      |     0 |    1 |     2 |
-- | A       | v0      |     0 |    1 |     4 |
-- | A       | v1      |     1 |    2 |     3 |

CALL treeNewChildElement('A', 'v0', 'v2');
-- SELECT * FROM `TreeNode` ORDER BY `depth`, `left`, `right`;
-- | keyRoot | keyNode | depth | left | right |
-- +---------+---------+-------+------+-------+
-- | B       | v0      |     0 |    1 |     2 |
-- | A       | v0      |     0 |    1 |     6 |
-- | A       | v2      |     1 |    2 |     3 |
-- | A       | v1      |     1 |    4 |     5 |

CALL treeNewChildElement('A', 'v1', 'v1.1');
SELECT * FROM `TreeNode` ORDER BY `depth`, `left`, `right`;
-- | keyRoot | keyNode | depth | left | right |
-- +---------+---------+-------+------+-------+
-- | B       | v0      |     0 |    1 |     2 |
-- | A       | v0      |     0 |    1 |     8 |
-- | A       | v2      |     1 |    2 |     3 |
-- | A       | v1      |     1 |    4 |     7 |
-- | A       | v1.1    |     2 |    5 |     6 |

CALL treeIsRoot('A', 'v0'); -- true
CALL treeIsRoot('B', 'v0'); -- true
CALL treeIsRoot('A', 'v1.1'); -- false

CALL treeIsLeaf('A', 'v0'); -- false
CALL treeIsLeaf('B', 'v0'); -- true
CALL treeIsLeaf('A', 'v1'); -- false
CALL treeIsLeaf('A', 'v2'); -- true
CALL treeIsLeaf('A', 'v1.1'); -- true

CALL treeGetDecendents('A', 'v0', 1000);
-- | keyRoot | keyNode | depth |
-- +---------+---------+-------+
-- | A       | v1      |     1 |
-- | A       | v1.1    |     2 |
-- | A       | v2      |     1 |
-- 
CALL treeGetDecendents('A', 'v0', 1);
-- | keyRoot | keyNode | depth |
-- +---------+---------+-------+
-- | A       | v1      |     1 |
-- | A       | v2      |     1 |
-- 
CALL treeGetAncestors('A', 'v1.1', 100);
-- | keyRoot | keyNode | depth |
-- +---------+---------+-------+
-- | A       | v0      |     0 |
-- | A       | v1      |     1 |

CALL treeGetAncestors('A', 'v1.1', 1);
-- | keyRoot | keyNode | depth |
-- +---------+---------+-------+
-- | A       | v1      |     1 |

CALL treeGetRoot('A', 'v1.1');
-- | keyNode |
-- +---------+
-- | v0      |

CALL treeGetLeaves('A');
-- | keyNode |
-- +---------+
-- | v1.1    |
-- | v2      |

CALL treeDeleteAChildElement('A', 'v1', FALSE);
SELECT * FROM `TreeNode` ORDER BY `depth`, `left`, `right`;
-- | keyRoot | keyNode | depth | left | right |
-- +---------+---------+-------+------+-------+
-- | B       | v0      |     0 |    1 |     2 |
-- | A       | v0      |     0 |    1 |     6 |
-- | A       | v2      |     1 |    2 |     3 |
-- | A       | v1.1    |     1 |    4 |     5 |

CALL treeDeleteBranch('A', 'v0');
SELECT * FROM `TreeNode` ORDER BY `depth`, `left`, `right`;
-- | keyRoot | keyNode | depth | left | right |
-- +---------+---------+-------+------+-------+
-- | B       | v0      |     0 |    1 |     2 |

CALL treeNewRootElement('C', 'v0');
CALL treeNewChildElement('C', 'v0', 'v1');
CALL treeNewChildElement('C', 'v1', 'v1.2');
CALL treeNewChildElement('C', 'v1', 'v1.1');
CALL treeNewChildElement('C', 'v1.1', 'v1.1.1');
SELECT * FROM `TreeNode` ORDER BY `depth`, `left`, `right`;
-- | keyRoot | keyNode | depth | left | right |
-- +---------+---------+-------+------+-------+
-- | B       | v0      |     0 |    1 |     2 |
-- | C       | v0      |     0 |    1 |    10 |
-- | C       | v1      |     1 |    2 |     9 |
-- | C       | v1.1    |     2 |    3 |     6 |
-- | C       | v1.2    |     2 |    7 |     8 |
-- | C       | v1.1.1  |     3 |    4 |     5 |

CALL treeDeleteBranch('C', 'v1.1');
SELECT * FROM `TreeNode` ORDER BY `depth`, `left`, `right`;
-- | keyRoot | keyNode | depth | left | right |
-- +---------+---------+-------+------+-------+
-- | B       | v0      |     0 |    1 |     2 |
-- | C       | v0      |     0 |    1 |     6 |
-- | C       | v1      |     1 |    2 |     5 |
-- | C       | v1.2    |     2 |    3 |     4 |

CALL treeDelete('B');
SELECT * FROM `TreeNode` ORDER BY `depth`, `left`, `right`;
-- | keyRoot | keyNode | depth | left | right |
-- +---------+---------+-------+------+-------+
-- | C       | v0      |     0 |    1 |     6 |
-- | C       | v1      |     1 |    2 |     5 |
-- | C       | v1.2    |     2 |    3 |     4 |
