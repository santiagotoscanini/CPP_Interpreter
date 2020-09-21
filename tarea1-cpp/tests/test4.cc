#include <stdexcept>
#include <vector>
#include "grade.h"
#include "median.h"
#include "Student_info.h"

using std::domain_error;  using std::vector;


// compute a student's overall grade from midterm and final exam grades and homework grade
double grade(double midterm, double final, double homework)
{
	return 0.2 * midterm + 0.4 * final + 0.4 * homework;
}

// compute a student's overall grade from midterm and final exam grades
// and vector of homework grades.
// this function does not copy its argument, because `median' does so for us.
double grade(double midterm, double final, const vector<double>& hw)
{
	if (hw.size() == 0)
		throw domain_error("student has done no homework");
	return grade(median(hw), midterm, final);
}

double grade(const Student_info& s)
{
	return grade(s.midterm, s.final, s.homework);
}

// PDefs [DUs (EQcte [QId (Id "std"),QId (Id "domain_error")]),DUs (EQcte [QId (Id "std"),QId (Id "vector")]),DFun (TypeB BuilInType_double) (Id "grade") [ADecl (TypeB BuilInType_double) (Id "midterm"),ADecl (TypeB BuilInType_double) (Id "final"),ADecl (TypeB BuilInType_double) (Id "homework")] [SReturn (EPlus (EPlus (ETimes (EDouble 0.2) (EQcte [QId (Id "midterm")])) (ETimes (EDouble 0.4) (EQcte [QId (Id "final")]))) (ETimes (EDouble 0.4) (EQcte [QId (Id "homework")])))],DFun (TypeB BuilInType_double) (Id "grade") [ADecl (TypeB BuilInType_double) (Id "midterm"),ADecl (TypeB BuilInType_double) (Id "final"),AConst (ADecIdVec (QIdT (Id "vector") [TypeB BuilInType_double]) (Id "hw"))] [SIf (EEq (EPEstr (EQcte [QId (Id "hw")]) (EApp (Id "size") [])) (EInt 0)) (SExp (EExcp (EApp (Id "domain_error") [EString ["student has done no homework"]]))),SReturn (ECallEx (Id "grade") (EApp (Id "median") [EQcte [QId (Id "hw")]]) [EQcte [QId (Id "midterm")],EQcte [QId (Id "final")]])],DFun (TypeB BuilInType_double) (Id "grade") [AConst (ADecIdVec (QId (Id "Student_info")) (Id "s"))] [SReturn (ECallEx (Id "grade") (EPEstr (EQcte [QId (Id "s")]) (EQcte [QId (Id "midterm")])) [EPEstr (EQcte [QId (Id "s")]) (EQcte [QId (Id "final")]),EPEstr (EQcte [QId (Id "s")]) (EQcte [QId (Id "homework")])])]]