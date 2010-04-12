//===--- CGRecordLayout.h - LLVM Record Layout Information ------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef CLANG_CODEGEN_CGRECORDLAYOUT_H
#define CLANG_CODEGEN_CGRECORDLAYOUT_H

#include "llvm/ADT/DenseMap.h"
#include "clang/AST/Decl.h"
namespace llvm {
  class raw_ostream;
  class Type;
}

namespace clang {
namespace CodeGen {

/// Helper object for describing how to generate the code for access to a
/// bit-field.
class CGBitFieldInfo {
public:
  CGBitFieldInfo(const llvm::Type *FieldTy, unsigned FieldNo,
                 unsigned Start, unsigned Size, bool IsSigned)
    : FieldTy(FieldTy), FieldNo(FieldNo),
      Start(Start), Size(Size), IsSigned(IsSigned) {}

  const llvm::Type *FieldTy;
  unsigned FieldNo;

  unsigned Start;
  unsigned Size;
  bool IsSigned : 1;

  void print(llvm::raw_ostream &OS) const;
  void dump() const;
};

/// CGRecordLayout - This class handles struct and union layout info while
/// lowering AST types to LLVM types.
///
/// These layout objects are only created on demand as IR generation requires.
class CGRecordLayout {
  friend class CodeGenTypes;

  CGRecordLayout(const CGRecordLayout&); // DO NOT IMPLEMENT
  void operator=(const CGRecordLayout&); // DO NOT IMPLEMENT

private:
  /// The LLVMType corresponding to this record layout.
  const llvm::Type *LLVMType;

  /// Map from (non-bit-field) struct field to the corresponding llvm struct
  /// type field no. This info is populated by record builder.
  llvm::DenseMap<const FieldDecl *, unsigned> FieldInfo;

  /// Map from (bit-field) struct field to the corresponding llvm struct type
  /// field no. This info is populated by record builder.
  llvm::DenseMap<const FieldDecl *, CGBitFieldInfo> BitFields;

  /// Whether one of the fields in this record layout is a pointer to data
  /// member, or a struct that contains pointer to data member.
  bool ContainsPointerToDataMember : 1;

public:
  CGRecordLayout(const llvm::Type *T, bool ContainsPointerToDataMember)
    : LLVMType(T), ContainsPointerToDataMember(ContainsPointerToDataMember) {}

  /// \brief Return the LLVM type associated with this record.
  const llvm::Type *getLLVMType() const {
    return LLVMType;
  }

  /// \brief Check whether this struct contains pointers to data members.
  bool containsPointerToDataMember() const {
    return ContainsPointerToDataMember;
  }

  /// \brief Return the BitFieldInfo that corresponds to the field FD.
  unsigned getLLVMFieldNo(const FieldDecl *FD) const {
    assert(!FD->isBitField() && "Invalid call for bit-field decl!");
    assert(FieldInfo.count(FD) && "Invalid field for record!");
    return FieldInfo.lookup(FD);
  }

  /// \brief Return llvm::StructType element number that corresponds to the
  /// field FD.
  const CGBitFieldInfo &getBitFieldInfo(const FieldDecl *FD) const {
    assert(FD->isBitField() && "Invalid call for non bit-field decl!");
    llvm::DenseMap<const FieldDecl *, CGBitFieldInfo>::const_iterator
      it = BitFields.find(FD);
    assert(it != BitFields.end()  && "Unable to find bitfield info");
    return it->second;
  }

  void print(llvm::raw_ostream &OS) const;
  void dump() const;
};

}  // end namespace CodeGen
}  // end namespace clang

#endif
