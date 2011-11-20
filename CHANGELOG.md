0.2.3
-----
* Added support for models that declare a has_one relationships, these would error out in the previous versions.


0.2.2
-----
* Enhancements
  * Added support for aliased associations ( belongs_to :something, :class_name => 'SomethingElse'). In previous version these would raise an 'uninitialized constant' error.

0.2.1
-----
* Initial release
