!!****m* ABINIT/m_hastable
!! NAME
!! m_hashtable
!!
!! FUNCTION
!! This module provide a string: value pair hash table
!! COPYRIGHT
!! Taken from http://fortranwiki.org/fortran/show/hash+table+example
!! The code is originally written by Izaak Beekman under the LGPL license.
!! Adapted for usage in Abinit by hexu
!!
!! Note: the behavior is different from the origial version
!! The value will be overwritten in this version, whereas it is ignored in the
!! original version if the key is already in the table (why??!!). 
!!
!! Note2:!!!!!!!!!!!!!!!!! FIXME
!! It does not handle white space at the end of string correctly. It does not affect
!! the usage in Multibinit but BE CAREFUL. 
!!
!! Below is the original Copyright.
!!=======================================
!! Copyright (C) Izaak Beekman 2010
!! This program is free software: you can redistribute it and/or modify
!! it under the terms of the GNU Lesser General Public License as published by
!! the Free Software Foundation, either version 3 of the License, or
!! (at your option) any later version.
!!
!! This program is distributed in the hope that it will be useful,
!! but WITHOUT ANY WARRANTY; without even the implied warranty of
!! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!! GNU Lesser General Public License for more details.
!! You should have received a copy of the GNU Lesser General Public License
!! along with this program.  If not, see <http://www.gnu.org/licenses/>.
!!
!! SOURCE

#if defined HAVE_CONFIG_H
#include "config.h"
#endif

#include "abi_common.h"

MODULE m_hashtable_strval

!!***
  use defs_basis
  use m_errors
  use m_abicore

  IMPLICIT NONE ! Use strong typing
  INTEGER, PARAMETER :: tbl_size = 50

  TYPE sllist
     TYPE(sllist), POINTER :: child => NULL()
     CHARACTER(len=:), ALLOCATABLE :: key
     real(dp) :: val
   CONTAINS
     PROCEDURE :: put  => put_sll
     PROCEDURE :: get  => get_sll
     PROCEDURE :: free => free_sll
     PROCEDURE :: sum_val => sum_val_sll
     procedure :: sum_entry => sum_entry_sll
     procedure :: print_all => print_all_sll
     procedure :: print_entry => print_entry_sll
  END TYPE sllist

  TYPE hash_table_t
     TYPE(sllist), DIMENSION(:), ALLOCATABLE :: vec
     INTEGER                                 :: vec_len = 0
     LOGICAL                                 :: is_init = .FALSE.
   CONTAINS
     PROCEDURE :: init => init_hash_table_t
     PROCEDURE :: put  => put_hash_table_t
     PROCEDURE :: get  => get_hash_table_t
     PROCEDURE :: free => free_hash_table_t
     PROCEDURE :: sum_val => sum_val_hash_table_t
     PROCEDURE :: print_all => print_all_hash_table_t
     procedure :: print_entry => print_entry_hash_table_t
  END TYPE hash_table_t

  PUBLIC :: hash_table_t

CONTAINS

  RECURSIVE SUBROUTINE put_sll(list,key,val)
    CLASS(sllist),    INTENT(inout) :: list
    CHARACTER(len=*), INTENT(in)    :: key
    real(dp), intent(in)  :: val
    INTEGER                         :: keylen

    keylen = LEN(key)
    IF (ALLOCATED(list%key)) THEN
       IF (list%key /= key) THEN
          IF ( .NOT. ASSOCIATED(list%child)) then
             ABI_MALLOC_SCALAR(list%child)
          end IF

          CALL put_sll(list%child,key,val)
       else
          list%val=val
       END IF
    ELSE
       IF (.NOT. ALLOCATED(list%key)) &
            ABI_MALLOC_TYPE_SCALAR(CHARACTER(len=keylen), list%key)
       list%key = key
       list%val = val
    END IF
  END SUBROUTINE put_sll


  RECURSIVE SUBROUTINE get_sll(list,key,val)
    CLASS(sllist),                 INTENT(in)    :: list
    CHARACTER(len=*),              INTENT(in)    :: key
    real(dp),                      INTENT(out)   :: val
    INTEGER                                      :: vallen

    vallen = 0
    IF (ALLOCATED(list%key) .AND. (list%key == key)) THEN
       val = list%val
    ELSE IF(ASSOCIATED(list%child)) THEN ! keep going
       CALL get_sll(list%child,key,val)
    ELSE ! At the end of the list, no key found
       return
    END IF
  END SUBROUTINE get_sll


  RECURSIVE SUBROUTINE free_sll(list)
    CLASS(sllist), INTENT(inout) :: list
    IF (ASSOCIATED(list%child)) THEN
       CALL free_sll(list%child)
       ABI_FREE_SCALAR(list%child)
    END IF
    list%child => NULL()
    ABI_SFREE(list%key)
  END SUBROUTINE free_sll

  recursive function sum_val_sll(self) result(s)
    class(sllist), intent(in) :: self
    real(dp) :: s
    s=0.0_dp
    if (allocated(self%key)) then
       s=s+self%val
       if(associated(self%child)) then
          s=s+self%child%sum_val()
       endif
    end if
  end function sum_val_sll

  recursive function sum_entry_sll(self, label, prefix) result(s)
    class(sllist), intent(in) :: self
    character(*), optional, intent(in) :: label
    character(*), optional, intent(in) :: prefix
    real(dp) :: s

    integer :: length

    if((.not. present(prefix)) .and. (.not. present(label))) then
      ABI_ERROR('Label and prefix not present.')
    endif
    if(present(label) .and. present(prefix)) then
      ABI_ERROR('Label and prefix present, only specify one of the two.')
    endif

    if(present(prefix)) length=len(prefix)

    s=0.0_dp
    if (allocated(self%key)) then
      if(present(prefix)) then
        if(self%key(1:length) .eq. prefix) then
          s=s+self%val
        endif
      else
        if(self%key .eq. label) then
          s=s+self%val
        endif
      endif
      if(associated(self%child)) then
        s=s+self%child%sum_entry(label=label, prefix=prefix)
      endif
    end if
  end function sum_entry_sll

  recursive subroutine print_all_sll(self)
    class(sllist), intent(in) :: self
    character(len=80) :: msg

    if (allocated(self%key)) then
      write(msg, "(A40, 1X, ES13.5)") self%key, self%val 
      call wrtout(std_out,msg,'COLL')
      call wrtout(ab_out, msg, 'COLL')
      if(associated(self%child)) then
        call self%child%print_all()
      endif
    end if
  end subroutine print_all_sll

  recursive subroutine print_entry_sll(self, label, prefix)
    class(sllist), intent(in) :: self
    character(*), optional, intent(in) :: label
    character(*), optional, intent(in) :: prefix

    integer :: length
    character(len=80) :: msg

    if((.not. present(prefix)) .and. (.not. present(label))) then
      ABI_ERROR('Label and prefix not present.')
    endif
    if(present(label) .and. present(prefix)) then
      ABI_ERROR('Label and prefix present, only specify one of the two.')
    endif

    if(present(prefix)) then
      length=len(prefix)
    endif

    if (allocated(self%key)) then
      if(present(prefix)) then
        if(self%key(1:length) .eq. prefix) then
          write(msg, "(A40, 1X, ES13.5)") self%key, self%val
          call wrtout(std_out,msg,'COLL')
          call wrtout(ab_out, msg, 'COLL')
        endif
      else !not prefix but label present
        if(self%key .eq. label) then
          write(msg, "(A40, 1X, ES13.5)") self%key, self%val
          call wrtout(std_out,msg,'COLL')
          call wrtout(ab_out, msg, 'COLL')
        endif
      endif
      if(associated(self%child)) then
        call self%child%print_entry(label=label, prefix=prefix)
      endif
    endif

  end subroutine print_entry_sll

  SUBROUTINE init_hash_table_t(tbl,tbl_len)
    CLASS(hash_table_t),   INTENT(inout) :: tbl
    INTEGER,     OPTIONAL, INTENT(in)    :: tbl_len

    ABI_SFREE(tbl%vec)
    IF (PRESENT(tbl_len)) THEN
       ABI_MALLOC(tbl%vec, (tbl_len))
       tbl%vec_len = tbl_len
    ELSE
       ABI_MALLOC(tbl%vec, (tbl_size))
       tbl%vec_len = tbl_size
    END IF
    tbl%is_init = .TRUE.
  END SUBROUTINE init_hash_table_t

  ! The first part of the hashing procedure using the string
  ! collating sequence
  ELEMENTAL FUNCTION sum_string(str) RESULT(sig)
    CHARACTER(len=*), INTENT(in)   :: str
    INTEGER                        :: sig
    CHARACTER, DIMENSION(LEN(str)) :: tmp
    INTEGER :: i

    FORALL (i=1:LEN(str))
       tmp(i) = str(i:i)
    END FORALL
    sig = SUM(ICHAR(tmp))
  END FUNCTION sum_string


  SUBROUTINE put_hash_table_t(tbl,key,val)
    CLASS(hash_table_t), INTENT(inout) :: tbl
    CHARACTER(len=*),    INTENT(in)    :: key
    real(dp),            INTENT(in)    :: val
    INTEGER                            :: hash

    hash = MOD(sum_string(key),tbl%vec_len) +1
    CALL tbl%vec(hash)%put(key=key,val=val)
  END SUBROUTINE put_hash_table_t


  SUBROUTINE get_hash_table_t(tbl,key,val)
    CLASS(hash_table_t),           INTENT(in)    :: tbl
    CHARACTER(len=*),              INTENT(in)    :: key
    real(dp),                      INTENT(out)   :: val
    INTEGER                                      :: hash

    hash = MOD(sum_string(key),tbl%vec_len) + 1
    CALL tbl%vec(hash)%get(key=key,val=val)
  END SUBROUTINE get_hash_table_t


  SUBROUTINE free_hash_table_t(tbl)
    CLASS(hash_table_t), INTENT(inout) :: tbl    
    INTEGER     :: i, low, high

    low  = LBOUND(tbl%vec,dim=1)
    high = UBOUND(tbl%vec,dim=1) 
    IF (ALLOCATED(tbl%vec)) THEN
       DO i=low,high
          CALL tbl%vec(i)%free()
       END DO
       ABI_FREE(tbl%vec)
    END IF
    tbl%is_init = .FALSE.
  END SUBROUTINE free_hash_table_t

  
  function sum_val_hash_table_t(self, label, prefix) result(s)
    class(hash_table_t), intent(in) :: self
    character(len=*), optional, intent(in) :: label, prefix

    real(dp) :: s
    integer :: i
    s=0.0_dp
    if (.not.(self%is_init)) then
       return
    end if
    do i =1, self%vec_len
      if(present(label) .or. present(prefix)) then
        s=s+self%vec(i)%sum_entry(label=label, prefix=prefix)
      else
        s=s+ self%vec(i)%sum_val()
      endif
    end do
  end function sum_val_hash_table_t

  subroutine print_all_hash_table_t(self)
    class(hash_table_t), intent(in) :: self
    integer :: i, low, high
    low  = LBOUND(self%vec,dim=1)
    high = UBOUND(self%vec,dim=1) 

    if (allocated(self%vec)) then
       do i =low, high
          call self%vec(i)%print_all()
       end do
    end if
  end subroutine print_all_hash_table_t

  subroutine print_entry_hash_table_t(self, label, prefix)
    class(hash_table_t), intent(in) :: self
    character(len=*), optional, intent(in) :: label, prefix
    integer :: i, low, high
    low  = LBOUND(self%vec,dim=1)
    high = UBOUND(self%vec,dim=1)

    if (allocated(self%vec)) then
       do i =low, high
          call self%vec(i)%print_entry(label=label, prefix=prefix)
       end do
    end if
  end subroutine print_entry_hash_table_t




end module m_hashtable_strval
